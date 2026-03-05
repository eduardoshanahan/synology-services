# Outline (hhnas4)

Internal wiki / knowledge base stack for `hhnas4`.

## Purpose

- Runs Outline behind the Synology DSM reverse proxy.
- Keeps Outline application storage and PostgreSQL local to the NAS.
- Uses shared Redis endpoint `redis.internal.example` for cache/queue state.
- Uses a single Compose project that matches the other `hhnas4` stacks.
- Uses Synology host networking, like `archivebox`, so the stack uses the NAS
  resolver directly instead of the default Docker bridge DNS path.

## Layout

- `compose.yaml`
- `.env.example`
- `.env.sops` (recommended tracked encrypted source)
- `deploy.sh`

## Runtime storage on NAS

Default target directory:

```text
/volume1/docker/homelab/hhnas4/outline
```

Docker-managed persistent volumes:

```text
outline_storage_data
outline_postgres_data
```

## Deploy

From this repository:

```bash
cd hhnas4/outline
./deploy.sh hhnas4.internal.example
```

Optional target directory override:

```bash
./deploy.sh hhnas4.internal.example /volume1/docker/homelab/hhnas4/outline
```

## First-start rules

- Preferred: keep the committed encrypted source in `.env.sops` and use
  `./deploy.sh --update-env` to decrypt locally and sync the runtime `.env` to
  the NAS.
- Fallback: keep a local ignored `.env` and use `./deploy.sh --update-env`.
- Generate fresh `SECRET_KEY` and `UTILS_SECRET`:
  - `openssl rand -hex 32`
- Set a real PostgreSQL password and keep `DATABASE_URL` aligned with
  `POSTGRES_PASSWORD`.
- Set `URL=https://outline.internal.example`.
- Configure at least one real auth path before relying on the install:
  - the current deployed setup uses SMTP magic-link sign-in
  - OIDC is optional and can be added later if needed
- If using SMTP-only auth, leave the `OIDC_*` variables empty.
- Use exactly one SMTP configuration mode:
  - either `SMTP_SERVICE`
  - or explicit `SMTP_HOST` / `SMTP_PORT` / related settings
- This stack binds Outline to loopback by default:
  - Outline listens directly on `127.0.0.1:3010`
  - Postgres listens directly on `127.0.0.1:15432`
- Shared Redis endpoint must be reachable:
  - `redis.internal.example:6379`
  - `REDIS_URL` should include password auth:
    - `redis://:<password>@redis.internal.example:6379`
- If `.env.sops` exists, `sops` must be available locally. This repo's
  `nix develop` shell now includes it.

## Reverse Proxy (DSM)

Recommended public shape:

- Client URL: `https://outline.internal.example/`
- DSM reverse proxy backend: `http://127.0.0.1:3010`

Keep TLS termination in DSM. Outline itself should continue serving plain HTTP
on loopback only.

## Validation goals

- `docker compose ps` shows `outline` and `postgres` healthy / running.
- `curl -sSI http://127.0.0.1:3010/` returns a page or redirect from the NAS.
- `curl -skI https://outline.internal.example/` returns a page or redirect
  through the DSM reverse proxy.
- Outline can complete initial sign-in with SMTP magic-link auth.

## Backup note

- PostgreSQL is the primary source of truth. Prefer logical dumps (`pg_dump`) as
  the main backup path.
- The local file storage volume also contains uploaded attachments and should be
  included in backups.
