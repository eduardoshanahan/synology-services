# hhnas4 Docker DNS and Address Pool Runbook

Goal: keep bridge-mode Docker services on `hhnas4` on one stable networking
policy:

- one host-wide Docker daemon DNS policy
- one reserved Docker bridge address pool
- one predictable DSM firewall posture for bridge egress

This public runbook uses sanitized placeholders for the live Docker bridge
pool, bridge gateway, and resolver IPs. Keep the real current values in the
private companion repo.

## Target shape

- Reserve `<docker-bridge-pool-cidr>` for Docker user-defined bridge networks
  on `hhnas4`.
- Keep Docker's default `bridge` network on `<docker-default-bridge-cidr>`.
- Configure Docker daemon DNS globally on `hhnas4` so bridge-mode containers
  resolve FQDN dependencies through the intended LAN resolvers.
- Add one DSM firewall allow rule for source `<docker-bridge-pool-cidr>`.
- Recreate bridge-mode stacks so they receive addresses from that pool.
- Remove older ad-hoc Docker bridge firewall rules once the new pool is in use
  and validated.

## Canonical DNS policy

For `hhnas4`, daemon DNS is the normal resolver model for all bridge-mode
services.

- Service configs should keep dependency FQDNs such as `postgres.<domain>` and
  `redis.<domain>`.
- Per-stack `dns:` blocks should not be the default fix path.
- Docker will still write `nameserver 127.0.0.11` inside containers.
- The daemon `dns` list controls which upstream resolvers Docker's embedded
  resolver forwards to.

If one service needs a temporary DNS override for incident rollback, treat it
as an explicit short-lived exception and remove it once host policy is healthy
again.

## Why

Without a reserved address pool, Synology Container Manager / Docker may create
Compose bridge networks on ranges such as:

- `172.18.0.0/16`
- `172.30.0.0/24`
- `198.18.64.0/20`
- `198.19.224.0/20`

That makes DSM firewall policy brittle, because each newly created network may
need its own source allow rule.

## Recommended Docker pool

Use this Docker daemon config shape:

```json
{
  "bip": "<docker-default-bridge-gateway-cidr>",
  "dns": [
    "<primary-lan-dns-ip>",
    "<secondary-lan-dns-ip>"
  ],
  "default-address-pools": [
    {
      "base": "<docker-bridge-pool-cidr>",
      "size": 24
    }
  ]
}
```

This keeps Docker's default `bridge` network on
`<docker-default-bridge-cidr>` and lets
Docker allocate user-defined bridge networks as `/24` subnets inside
`<docker-bridge-pool-cidr>`.

The daemon `dns` setting is host-wide and intentionally keeps application
configs using FQDNs such as `postgres.<domain>` and `redis.<domain>` instead
of pinned service IPs.

Current live validation should always confirm the real resolver list from:

- `/var/packages/ContainerManager/etc/dockerd.json`

Keep exact live resolver IPs in the private companion repo rather than in this
public runbook.

Example future networks:

- `<docker-bridge-subnet-a>`
- `<docker-bridge-subnet-b>`
- `<docker-bridge-subnet-c>`

## DSM firewall rule

Add one allow rule in DSM firewall policy for:

- Source IP: `<docker-bridge-pool-cidr>`

Place it before the final drop rule, alongside your existing LAN allow rules.

This rule should cover container egress from bridge-mode services to LAN
destinations such as:

- Pi services
- NAS-local services
- DNS (`<dns-lan-ip>`)
- reverse proxies
- trackers / outbound internet flows if your policy distinguishes LAN/WAN paths

## Migration steps

1. Configure the Docker / Container Manager default address pool on `hhnas4`
   to `<docker-bridge-pool-cidr>`, set `bip` to
   `<docker-default-bridge-gateway-cidr>`, and set the daemon `dns` list to
   the intended LAN resolvers.
1. Add the DSM firewall allow rule for source `<docker-bridge-pool-cidr>`.
1. Restart `pkg-ContainerManager-dockerd.service`.
1. Recreate bridge-mode Compose stacks so their containers pick up the new
   daemon DNS settings and their networks are recreated from the new pool when
   needed.
1. Validate container egress from one or two representative services.
1. Remove older specific Docker subnet rules after validation.

## Important operational note

Changing the default address pool does not move existing networks in place.
Existing bridge networks keep their current subnets until those networks are
removed and recreated.

That means a stack restart is not enough if the backing Docker network is
reused. The network itself must be recreated for address-pool changes, and
containers must at least be recreated for daemon-level DNS changes.

Typical recreate pattern per stack:

```bash
cd /volume1/docker/homelab/hhnas4/<stack>
sudo /usr/local/bin/docker compose down
sudo /usr/local/bin/docker compose up -d
```

If you only changed daemon DNS and do not need a new network subnet, a focused
recreate is enough:

```bash
cd /volume1/docker/homelab/hhnas4/<stack>
sudo /usr/local/bin/docker compose up -d --force-recreate
```

For heavily used services, recreate them in a controlled order to avoid
unnecessary downtime.

## Suggested validation

After recreating a stack, confirm its network is in the reserved pool:

```bash
sudo /usr/local/bin/docker network inspect <network-name> --format '{{range .IPAM.Config}}{{println .Subnet}}{{end}}'
```

Then confirm a representative container can resolve homelab dependencies:

```bash
sudo /usr/local/bin/docker exec <container> sh -lc 'getent hosts postgres.<domain> redis.<domain>'
```

Confirm the daemon DNS policy is present:

```bash
sudo cat /var/packages/ContainerManager/etc/dockerd.json
sudo /usr/local/bin/docker info | sed -n '1,160p'
```

Expected:

- `dockerd.json` includes `bip`, `dns`, and `default-address-pools`
- `Default Address Pools` includes `<docker-bridge-pool-cidr>`
- containerized apps resolve shared dependency FQDNs successfully
- reverse-proxied apps that depend on DNS-backed shared services recover after
  container recreation
- `verify-docker-dns.sh <target-host>` passes from the repo root

## Temporary bridge-egress helper

`ensure-docker-bridge-lan-egress.sh` remains useful as an emergency or
diagnostic tool, but it should not be the primary long-term policy mechanism if
the DSM firewall is updated to a stable reserved Docker range.

## Current exceptions on `hhnas4`

- `paperless-net` is explicitly pinned in compose and must be migrated by
  changing `PAPERLESS_DOCKER_SUBNET`, not by relying on Docker's default pool.
- `hhlab-shared-db` is an external shared network and must be migrated as its
  own maintenance action.
- `promtail` can run on a normal bridge network; host networking is not
  required for Docker-socket-based log discovery in this repo.
