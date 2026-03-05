# Redis (nas-host)

Shared Redis server for internal services on `nas-host`.

## Purpose

- Provides one reusable Redis endpoint for services in `internal.example`.
- Replaces per-app embedded Redis sidecars where shared Redis is preferred.
- Keeps Redis internal-only (no DSM reverse proxy exposure).

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
- `.env.sops` (recommended tracked encrypted source)
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

If you keep local `.env` (or encrypted `.env.sops`), push it explicitly:

```bash
./deploy.sh nas-host.internal.example --update-env
```

## First-start rules

- Set a strong `REDIS_PASSWORD` before first production start.
- Keep this endpoint internal-only; do not expose Redis through DSM reverse proxy.
- Use authenticated client URLs, for example:
  - `redis://:<password>@redis.internal.example:6379`

## Validation goals

- `docker compose ps` shows `redis` healthy.
- From NAS: `redis-cli -h 127.0.0.1 -p 6379 -a '<password>' ping` returns `PONG`.
- Client services can connect using authenticated `REDIS_URL`.

## Backup note

- AOF persistence is enabled in this stack (`appendonly yes`).
- Include `redis_data` in backup and restore drill procedures.
