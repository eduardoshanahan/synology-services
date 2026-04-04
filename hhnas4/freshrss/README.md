# FreshRSS (hhnas4)

FreshRSS stack on `hhnas4`, intended to sit behind DSM reverse proxy.

## Runtime model

- Binds to loopback by default (`127.0.0.1:${FRESHRSS_HOST_PORT:-8095}`).
- Uses persistent Docker volumes for data and extensions.
- Uses built-in cron (`CRON_MIN`) for feed refresh.
- Uses shared PostgreSQL on `postgres.internal.example:5433`.

## First-time database setup (shared Postgres)

Create a dedicated role and DB before running the FreshRSS web installer:

```bash
psql -h postgres.internal.example -p 5433 -U postgres -d postgres -c "CREATE ROLE freshrss LOGIN PASSWORD '<strong-password>';"
psql -h postgres.internal.example -p 5433 -U postgres -d postgres -c "CREATE DATABASE freshrss OWNER freshrss;"
```

In the FreshRSS installer, use:

- DB type: `PostgreSQL`
- DB host: `postgres.internal.example:5433`
- DB name: `freshrss`
- DB user: `freshrss`
- DB password: value from your private `.env.sops`

## Reverse proxy prerequisite

Ensure your DSM reverse proxy routes `freshrss.internal.example` to
`127.0.0.1:${FRESHRSS_HOST_PORT:-8095}` on `hhnas4`.

## Deploy

```bash
./deploy.sh hhnas4 --update-env
```

## Validate

```bash
ssh hhnas4 "cd /volume1/docker/homelab/hhnas4/freshrss && docker compose ps"
ssh hhnas4 "curl -sSI http://127.0.0.1:8095/ | head -n 5"
```
