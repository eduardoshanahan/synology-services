# Outline (nas-host)

Internal wiki / knowledge base stack for `nas-host`.

## Purpose

- Runs Outline behind the Synology DSM reverse proxy.
- Keeps Outline application storage local to the NAS.
- Uses shared PostgreSQL endpoint `postgres.internal.example:5433`.
- Uses shared Redis endpoint `redis.internal.example` for cache/queue state.
- Uses shared SMTP relay endpoint `smtp-relay.internal.example:2525`.
- Uses a single Compose project that matches the other `nas-host` stacks.
- Uses bridge networking with loopback-only publish on the NAS host:
  `127.0.0.1:${OUTLINE_PORT}:3010`.

## Layout

- `compose.yaml`
- `.env.example`
- `.env.sops` (recommended tracked encrypted source)
- `deploy.sh`

## Runtime storage on NAS

Default target directory:

```text
/volume1/docker/homelab/nas-host/outline
```

Docker-managed persistent volumes:

```text
outline_storage_data
```

## Deploy

From this repository:

```bash
cd nas-host/outline
./deploy.sh nas-host.internal.example
```

Optional target directory override:

```bash
./deploy.sh nas-host.internal.example /volume1/docker/homelab/nas-host/outline
```

## First-start rules

- Preferred: keep the committed encrypted source in `.env.sops` and use
  `./deploy.sh --update-env` to decrypt locally and sync the runtime `.env` to
  the NAS.
- Fallback: keep a local ignored `.env` and use `./deploy.sh --update-env`.
- Generate fresh `SECRET_KEY` and `UTILS_SECRET`:
  - `openssl rand -hex 32`
- Set a real PostgreSQL password in `DATABASE_URL` for the shared DB role.
- Set `URL=https://outline.internal.example`.
- Configure at least one real auth path before relying on the install:
  - the current deployed setup uses SMTP magic-link sign-in
  - OIDC is optional and can be added later if needed
- If using SMTP-only auth, leave the `OIDC_*` variables empty.
- Use exactly one SMTP configuration mode:
  - either `SMTP_SERVICE`
  - or explicit `SMTP_HOST` / `SMTP_PORT` / related settings
- This stack publishes the container port on loopback by default:
  - host publish `127.0.0.1:${OUTLINE_PORT:-3010}` -> container `:3010`
  - `OUTLINE_HOST_BIND=127.0.0.1` keeps it local to the NAS
- Shared PostgreSQL endpoint must be reachable:
  - `postgres.internal.example:5433`
- Shared SMTP relay endpoint must be reachable:
  - `smtp-relay.internal.example:2525`
- Shared Redis endpoint must be reachable:
  - `redis.internal.example:6379`
  - `REDIS_URL` should include ACL username + password auth:
    - `redis://outline:<password>@redis.internal.example:6379`
- This stack intentionally relies on DNS names for shared dependencies
  (`postgres.internal.example`, `redis.internal.example`,
  `smtp-relay.internal.example`) and does not pin service IPs in Compose.
- This stack ships `certs/homelab-root-ca.crt` and mounts it into the Outline
  container as `NODE_EXTRA_CA_CERTS` so OIDC discovery/token calls to internal
  TLS endpoints (for example Authentik) are trusted.
- If `.env.sops` exists, `sops` must be available locally. This repo's
  `nix develop` shell now includes it.

## Migration from local Outline Postgres to shared Postgres

Run these only once when migrating an existing Outline deployment that still has
local `outline-postgres` data.

1. Create the shared role/database on `nas-host/postgres`:

```bash
ssh nas-host "cd /volume1/docker/homelab/nas-host/postgres && sudo /usr/local/bin/docker compose exec -T postgres psql -U postgres -c \"DO \\\$\\\$ BEGIN IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'outline') THEN CREATE ROLE outline LOGIN PASSWORD 'replace-me'; ELSE ALTER ROLE outline WITH LOGIN PASSWORD 'replace-me'; END IF; END \\\$\\\$;\""
ssh nas-host "cd /volume1/docker/homelab/nas-host/postgres && sudo /usr/local/bin/docker compose exec -T postgres psql -U postgres -c \"SELECT 'CREATE DATABASE outline OWNER outline' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'outline')\\\\gexec\""
```

1. Dump from local `outline-postgres` and restore into shared postgres:

```bash
ssh nas-host "cd /volume1/docker/homelab/nas-host/outline && sudo /usr/local/bin/docker compose exec -T outline-postgres pg_dump -U outline -d outline" > /tmp/outline.sql
ssh nas-host "cat > /tmp/outline.sql" < /tmp/outline.sql
ssh nas-host "cd /volume1/docker/homelab/nas-host/postgres && sudo /usr/local/bin/docker compose exec -T postgres psql -U postgres -d outline < /tmp/outline.sql"
```

1. Update Outline `.env` `DATABASE_URL` to shared postgres and redeploy with
`--update-env`.

1. After successful validation, remove the old local sidecar resources:

```bash
ssh nas-host "cd /volume1/docker/homelab/nas-host/outline && sudo /usr/local/bin/docker compose rm -s -f outline-postgres || true"
ssh nas-host "sudo /usr/local/bin/docker volume ls --format '{{.Name}}' | grep '^outline_postgres_data$' && sudo /usr/local/bin/docker volume rm outline_postgres_data || true"
```

## Reverse Proxy (DSM)

Recommended public shape:

- Client URL: `https://outline.internal.example/`
- DSM reverse proxy backend: `http://127.0.0.1:3010`

Keep TLS termination in DSM. Outline itself should continue serving plain HTTP
on loopback only.

## Validation goals

- `docker compose ps` shows only `outline` running in this stack.
- `curl -sSI http://127.0.0.1:3010/` returns a page or redirect from the NAS.
- `curl -skI https://outline.internal.example/` returns a page or redirect
  through the DSM reverse proxy.
- Outline can complete initial sign-in with SMTP magic-link auth.
- Outline can read/write documents with shared Postgres.

## Backup note

- PostgreSQL is the primary source of truth. Prefer logical dumps from the
  shared `nas-host/postgres` stack (`pg_dump`) as the main backup path.
- The local file storage volume also contains uploaded attachments and should be
  included in backups.
