# Redis (nas-host)

Shared Redis server for internal services on `nas-host`.

## Purpose

- Provides one reusable Redis endpoint for services in `internal.example`.
- Replaces per-app embedded Redis sidecars where shared Redis is preferred.
- Keeps Redis internal-only (no DSM reverse proxy exposure).
- Uses bridge networking with host port publish for `6379`.

## Service endpoint

- DNS name: `redis.internal.example`
- Default port in this stack: `6379`

## DNS prerequisite

Create an internal DNS A record before switching clients:

- `redis.internal.example -> <nas-host-lan-ip>`

Quick check from a client:

```bash
getent hosts redis.internal.example
```

## Layout

- `compose.yaml`
- `.env.example`
- sibling private `.env.sops` in `../synology-services-private/` (preferred tracked encrypted source)
- `deploy.sh`

## Runtime storage on NAS

Default target directory:

```text
/volume1/docker/homelab/nas-host/redis
```

Docker-managed persistent volume:

```text
redis_data
```

## Deploy

From this repository:

```bash
cd nas-host/redis
./deploy.sh nas-host.internal.example
```

Optional target directory override:

```bash
./deploy.sh nas-host.internal.example /volume1/docker/homelab/nas-host/redis
```

If you keep a sibling-private `.env.sops` (or a local fallback `.env` / `.env.sops` during transition), push it explicitly:

```bash
./deploy.sh nas-host.internal.example --update-env
```

## First-start rules

- Set strong ACL credentials before first production start:
  - `REDIS_ADMIN_USERNAME` / `REDIS_ADMIN_PASSWORD` for operator/admin access
  - `REDIS_OUTLINE_USERNAME` / `REDIS_OUTLINE_PASSWORD` for Outline
- ACL policy:
  - Admin user: full access (`+@all`)
  - Outline user: app access with restricted risk surface
    (`+@all -@admin -@dangerous +keys`)
  - `+keys` stays enabled for the Outline user because the app uses Redis key
    lookups for collaborative editing/session state.
- Keep this endpoint internal-only; do not expose Redis through DSM reverse proxy.
- Use authenticated client URLs with username, for example:
  - `redis://outline:<password>@redis.internal.example:6379`
- The `default` Redis user is disabled in this stack.

## Validation goals

- `docker compose ps` shows `redis` healthy.
- From NAS: `redis-cli -h 127.0.0.1 -p 6379 --user '<admin-user>' --pass '<admin-password>' ping` returns `PONG`.
- Client services can connect using authenticated `REDIS_URL`.

## Backup note

- AOF persistence is enabled in this stack (`appendonly yes`).
- Include `redis_data` in backup and restore drill procedures.
