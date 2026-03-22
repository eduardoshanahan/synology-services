# hhnas4 Docker Address Pool Runbook

Goal: stop Compose-created Docker bridge networks on `hhnas4` from drifting
across arbitrary subnets and make DSM firewall policy stable.

## Target shape

- Reserve `10.253.0.0/16` for Docker user-defined bridge networks on `hhnas4`.
- Keep Docker's default `bridge` network on `10.254.0.0/24`.
- Configure Docker daemon DNS globally on `hhnas4` so bridge-mode containers
  resolve FQDN dependencies through the intended LAN resolvers.
- Add one DSM firewall allow rule for source `10.253.0.0/16`.
- Recreate bridge-mode stacks so they receive addresses from that pool.
- Remove older ad-hoc Docker bridge firewall rules once the new pool is in use
  and validated.

## Why

Without a reserved address pool, Synology Container Manager / Docker may create
Compose bridge networks on ranges such as:

- `172.18.0.0/16`
- `172.23.0.0/16`
- `198.18.64.0/20`
- `198.19.224.0/20`

That makes DSM firewall policy brittle, because each newly created network may
need its own source allow rule.

## Recommended Docker pool

Use this Docker daemon config:

```json
{
  "bip": "10.254.0.1/24",
  "dns": [
    "<primary-lan-dns-ip>",
    "<secondary-lan-dns-ip>"
  ],
  "default-address-pools": [
    {
      "base": "10.253.0.0/16",
      "size": 24
    }
  ]
}
```

This keeps Docker's default `bridge` network on `10.254.0.0/24` and lets
Docker allocate user-defined bridge networks as `/24` subnets inside
`10.253.0.0/16`.

The `dns` setting is host-wide and intentionally keeps application configs
using FQDNs such as `postgres.<domain>` and `redis.<domain>` instead of pinned
service IPs. Docker still writes `nameserver 127.0.0.11` into container
`/etc/resolv.conf`; the daemon `dns` setting controls which upstream resolvers
that embedded Docker resolver forwards to.

Example future networks:

- `10.253.0.0/24`
- `10.253.1.0/24`
- `10.253.2.0/24`

## DSM firewall rule

Add one allow rule in DSM firewall policy for:

- Source IP: `10.253.0.0/16`

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
   to `10.253.0.0/16`, set `bip` to `10.254.0.1/24`, and set the daemon `dns`
   list to the intended LAN resolvers.
1. Add the DSM firewall allow rule for source `10.253.0.0/16`.
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

Typical pattern per stack:

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

Then confirm egress from a container:

```bash
sudo /usr/local/bin/docker exec <container> sh -lc 'ping -c 1 1.1.1.1; nslookup google.com'
```

Confirm the daemon DNS policy is present:

```bash
sudo /usr/local/bin/docker info | sed -n '1,120p'
```

Expected:

- `Default Address Pools` includes `10.253.0.0/16`
- containerized apps resolve shared dependency FQDNs successfully
- reverse-proxied apps that depend on DNS-backed shared services recover after
  container recreation

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
