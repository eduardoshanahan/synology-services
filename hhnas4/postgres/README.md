# PostgreSQL (nas-host)

Shared PostgreSQL server for internal services on `nas-host`.

## Purpose

- Provides one reusable PostgreSQL endpoint for services in `internal.example`.
- Uses one dedicated runtime/data path on Synology.
- Replaces ad-hoc per-app proxy patterns for DB connectivity.

## Service endpoint

- DNS name: `postgres.internal.example`
- Default port in this stack: `5433`

This stack defaults to `5433` to avoid clashing with legacy local PostgreSQL
listeners already bound on `nas-host` (`127.0.0.1:5432`).

## DNS prerequisite

Create an internal DNS A record before switching clients:

- `postgres.internal.example -> <nas-host-lan-ip>`

Quick check from a client:

```bash
getent hosts postgres.internal.example
```

## Layout

- `compose.yaml`
- `.env.example`
- sibling private `.env.sops` in `../synology-services-private/` (preferred tracked encrypted source)
- `deploy.sh`

## Runtime storage on NAS

Default target directory:

```text
/volume1/docker/homelab/nas-host/postgres
```

Docker-managed persistent volume:

```text
postgres_data
```

## Deploy

From this repository:

```bash
cd nas-host/postgres
./deploy.sh nas-host.internal.example
```

Optional target directory override:

```bash
./deploy.sh nas-host.internal.example /volume1/docker/homelab/nas-host/postgres
```

If you keep a sibling-private `.env.sops` (or a local fallback `.env` / `.env.sops` during transition), push it explicitly:

```bash
./deploy.sh nas-host.internal.example --update-env
```

## First-start rules

- Set a strong `POSTGRES_PASSWORD` before first production start.
- Keep this DB endpoint internal-only. Do not expose it through DSM reverse proxy.
- Create one DB role/user per service; do not share application users.

Example role/database bootstrap for a generic app:

```bash
psql -h postgres.internal.example -p 5433 -U postgres -d postgres -c "CREATE ROLE app_user LOGIN PASSWORD '<strong-password>';"
psql -h postgres.internal.example -p 5433 -U postgres -d postgres -c "CREATE DATABASE app_db OWNER app_user;"
psql -h postgres.internal.example -p 5433 -U postgres -d app_db -c "CREATE SCHEMA IF NOT EXISTS app AUTHORIZATION app_user;"
psql -h postgres.internal.example -p 5433 -U postgres -d postgres -c "ALTER ROLE app_user IN DATABASE app_db SET search_path TO app,public;"
```

## Validation goals

- `docker compose ps` shows `postgres` healthy.
- DNS resolves `postgres.internal.example` to the expected host.
- Service clients can connect with their own credentials.

## Backup note

- Prefer logical backups (`pg_dump` / `pg_dumpall`) on a schedule.
- Keep restore drills documented and tested.
