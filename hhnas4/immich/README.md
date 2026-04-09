# Immich (nas-host)

Immich photo/video management stack on `nas-host` using the official Docker
Compose model.

## Purpose

- Run Immich server + machine-learning workers directly on Synology.
- Keep library storage local on NAS paths.
- Use shared PostgreSQL and shared Redis services already running in homelab.
- Keep the Immich app endpoint loopback-only by default for DSM reverse proxy.
- Preserve compatibility with upstream release notes and compose/env contracts.

## Service endpoint

- DNS name: `immich.homelab.example`
- Default app port in this stack: `2283`
- Default bind mode: `127.0.0.1` (reverse-proxy oriented)

## Runtime storage on NAS

Default target directory:

```text
/volume1/docker/homelab/nas-host/immich
```

Default persistent path in `.env`:

```text
UPLOAD_LOCATION=/volume1/docker/homelab/nas-host/immich/library
```

Shared service env keys expected:

```text
DB_HOSTNAME DB_PORT DB_USERNAME DB_PASSWORD DB_DATABASE_NAME
REDIS_HOSTNAME REDIS_PORT REDIS_USERNAME REDIS_PASSWORD
```

Use your real homelab endpoint names in runtime/private env sources.

## Layout

- `compose.yaml`
- `.env.example`
- sibling private `.env.sops` in `../synology-services-private/` (preferred tracked encrypted source)
- `deploy.sh`

## Deploy

From this repository:

```bash
cd nas-host/immich
./deploy.sh nas-host
```

Optional target directory override:

```bash
./deploy.sh nas-host /volume1/docker/homelab/nas-host/immich
```

If you keep a sibling-private `.env.sops` (or a local fallback `.env` /
`.env.sops` during transition), push it explicitly:

```bash
./deploy.sh nas-host --update-env
```

## First-start rules

- Create a dedicated shared Postgres role + database for Immich before first production use.
- Create a dedicated shared Redis ACL user for Immich before first production use.
- Ensure required Postgres extensions exist in the Immich DB (run as superuser):
  - `vector`
  - `cube`
  - `earthdistance`
- If Redis ACLs deny `INFO` (startup ready check), grant `+info` for the Immich
  Redis user in addition to your base ACL policy.
- Keep `IMMICH_HOST_BIND=127.0.0.1` unless you intentionally want direct LAN
  access without DSM reverse proxy.
- Always check upstream release notes before upgrades.

## Reverse Proxy (DSM)

Recommended public shape:

- Client URL: `https://immich.homelab.example/`
- DSM reverse proxy backend: `http://127.0.0.1:2283`
- Use HTTPS on port `443` (no `:5001`); `:5001` is DSM management and will not
  route to Immich.
- Optional hardening: add an HTTP source rule for the same host in DSM reverse
  proxy so accidental `http://` requests do not fall through to the DSM
  web-management redirect page.

## Validate

```bash
ssh nas-host "cd /volume1/docker/homelab/nas-host/immich && docker compose ps"
ssh nas-host "curl -sS -m 6 -i http://127.0.0.1:2283 | sed -n '1,12p'"
ssh nas-host "cd /volume1/docker/homelab/nas-host/immich && docker compose logs --tail 120"
```

## Upgrade baseline

```bash
ssh nas-host "cd /volume1/docker/homelab/nas-host/immich && docker compose pull && docker compose up -d"
```

Read release notes before each upgrade:

- https://github.com/immich-app/immich/releases
