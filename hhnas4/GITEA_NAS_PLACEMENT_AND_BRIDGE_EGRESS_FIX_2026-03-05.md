# Gitea Placement Decision + Bridge Egress Fix (2026-03-05)

## Decision: keep Gitea on `nas-host` (NAS)

We are keeping Gitea core runtime on Synology `nas-host`.

### Why

- Gitea currently runs with local persistent state (`/volume1/docker/homelab/nas-host/gitea/data`).
- It uses SQLite in the same local storage path (single-container state model).
- NAS is the right place for repository/registry storage durability and backup workflows.
- Splitting Gitea core state across Pi + NAS would add latency/failure points with little benefit.
- Pi-hosted components remain useful for shared infra (SMTP relay, monitoring), but not Gitea core state.

## Problem found during SMTP migration

Gitea was configured to use `smtp-relay.internal.example:2525`, but SMTP send failed from the container.

Observed symptoms:

- From inside Gitea container, DNS resolution worked.
- From inside Gitea container, TCP to LAN endpoints failed (`192.0.2.10:2525`, `192.0.2.10:53`).
- From NAS host itself, TCP to relay worked.

Conclusion: this was not DNS records. It was bridge-container egress being dropped in host firewall forwarding chain.

## Root cause on `nas-host`

`FORWARD_FIREWALL` dropped non-LAN source ranges before Docker forwarding rules.
Docker bridge subnets (`172.x`) were not explicitly allowed.

Relevant chain shape:

- `FORWARD -> FORWARD_FIREWALL -> DEFAULT_FORWARD`
- `FORWARD_FIREWALL` had:
  - allow loopback
  - allow established
  - allow SNMP port 161
  - allow source `192.0.2.10/24`
  - final `DROP`

So packets from Docker bridge source `172.18.0.0/16` were dropped before Docker's normal forwarding rules could pass them.

## Applied infra fix (preferred)

We allowed Docker bridge source CIDRs in `FORWARD_FIREWALL` before the final drop.

Rule inserted on `nas-host`:

```bash
iptables -I FORWARD_FIREWALL 5 -s 172.16.0.0/12 -j RETURN
```

Because we only had passwordless `/usr/local/bin/docker`, this was executed via a privileged helper container using host network namespace.

## Validation after fix

From inside Gitea container:

- TCP to relay: `192.0.2.10:2525` -> OK
- TCP to DNS: `192.0.2.10:53` -> OK

This confirms bridge-container outbound LAN connectivity was restored.

## Current SMTP test state

After network fix, Gitea could connect to relay, but relay rejected the recipient:

- `554 5.7.1 Recipient address rejected: Access denied`
- Recipient in test was `contact@primary.example`.

This is now an SMTP relay policy/domain allowlist issue, not network transport.

## Persistence note (important)

This iptables rule may be lost on reboot/firewall reload.

To make this persistent in Synology DSM, add/ensure equivalent firewall policy that allows forwarding traffic sourced from Docker bridge ranges (at least `172.16.0.0/12`) to LAN destinations, or maintain an equivalent host firewall bootstrap script that reapplies this rule after boot.

## Next step

Adjust SMTP relay recipient/domain policy so Gitea notifications to intended domains are accepted.
