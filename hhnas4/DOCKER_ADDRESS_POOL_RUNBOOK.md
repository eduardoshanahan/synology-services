# hhnas4 Docker Address Pool Runbook

Goal: stop Compose-created Docker bridge networks on `hhnas4` from drifting
across arbitrary subnets and make DSM firewall policy stable.

## Target shape

- Reserve `172.30.0.0/16` for Docker user-defined bridge networks on `hhnas4`.
- Add one DSM firewall allow rule for source `172.30.0.0/16`.
- Recreate bridge-mode stacks so they receive addresses from that pool.
- Remove older ad-hoc Docker bridge firewall rules once the new pool is in use
  and validated.

## Why

Without a reserved address pool, Synology Container Manager / Docker may create
Compose bridge networks on ranges such as:

- `172.18.0.0/16`
- `172.23.0.0/16`
- `192.0.2.10/20`
- `192.0.2.10/20`

That makes DSM firewall policy brittle, because each newly created network may
need its own source allow rule.

## Recommended Docker pool

Use this logical pool:

```json
{
  "default-address-pools": [
    {
      "base": "172.30.0.0/16",
      "size": 24
    }
  ]
}
```

This lets Docker allocate user-defined bridge networks as `/24` subnets inside
`172.30.0.0/16`.

Example future networks:

- `172.30.0.0/24`
- `172.30.1.0/24`
- `172.30.2.0/24`

## DSM firewall rule

Add one allow rule in DSM firewall policy for:

- Source IP: `172.30.0.0/16`

Place it before the final drop rule, alongside your existing LAN allow rules.

This rule should cover container egress from bridge-mode services to LAN
destinations such as:

- Pi services
- NAS-local services
- DNS (`192.0.2.10`)
- reverse proxies
- trackers / outbound internet flows if your policy distinguishes LAN/WAN paths

## Migration steps

1. Configure the Docker / Container Manager default address pool on `hhnas4`
   to `172.30.0.0/16`.
1. Add the DSM firewall allow rule for source `172.30.0.0/16`.
1. Recreate bridge-mode Compose stacks so their networks are recreated from the
   new pool.
1. Validate container egress from one or two representative services.
1. Remove older specific Docker subnet rules after validation.

## Important operational note

Changing the default address pool does not move existing networks in place.
Existing bridge networks keep their current subnets until those networks are
removed and recreated.

That means a stack restart is not enough if the backing Docker network is
reused. The network itself must be recreated.

Typical pattern per stack:

```bash
cd /volume1/docker/homelab/hhnas4/<stack>
sudo /usr/local/bin/docker compose down
sudo /usr/local/bin/docker compose up -d
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

## Temporary bridge-egress helper

`ensure-docker-bridge-lan-egress.sh` remains useful as an emergency or
diagnostic tool, but it should not be the primary long-term policy mechanism if
the DSM firewall is updated to a stable reserved Docker range.
