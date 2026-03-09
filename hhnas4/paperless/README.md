# Paperless-ngx (nas-host)

Shared Paperless-ngx stack on `nas-host` using centralized dependencies.

## Purpose

- Runs Paperless-ngx application on NAS-hosted runtime.
- Uses shared PostgreSQL and Redis services on `nas-host`.
- Uses shared Apache Tika and Gotenberg services for extraction/conversion.
- Keeps primary app endpoint internal-only (typically via DSM reverse proxy).

## Service endpoint

- DNS name: `paperless.internal.example`
- Default app port in this stack: `8010`

## Dependency endpoints

- PostgreSQL: `postgres.internal.example:5433`
- Redis: `redis.internal.example:6379`
- Apache Tika: `tika.internal.example:9998`
- Gotenberg: `gotenberg.internal.example:3001`

## Layout

- `compose.yaml`
- `.env.example`
- `.env.sops` (recommended tracked encrypted source)
- `deploy.sh`

## Runtime storage on NAS

Default target directory:

```text
/volume1/docker/homelab/nas-host/paperless
```

Persistent Docker volumes:

```text
paperless_data
paperless_media
```

Bind-mounted import/export directories under target dir:

```text
consume/
export/
```

## Deploy

From this repository:

```bash
cd nas-host/paperless
./deploy.sh nas-host.internal.example
```

Optional target directory override:

```bash
./deploy.sh nas-host.internal.example /volume1/docker/homelab/nas-host/paperless
```

If you keep local `.env` (or encrypted `.env.sops`), push it explicitly:

```bash
./deploy.sh nas-host.internal.example --update-env
```

## First-start rules

- Set strong values in `.env` before production use:
  - `PAPERLESS_SECRET_KEY`
  - `PAPERLESS_DBPASS`
  - Redis credential inside `PAPERLESS_REDIS`
- Ensure `PAPERLESS_DNS` points at an internal resolver that serves
  `*.internal.example` (default: `192.0.2.10`).
- Keep Paperless internal-only; do not expose port `8000` publicly.
- Create dedicated DB role/database on shared Postgres:
  - role: `paperless`
  - database: `paperless`
- Create dedicated Redis ACL user/password for Paperless and use that in
  `PAPERLESS_REDIS`.

## Postgres bootstrap example

```bash
psql -h postgres.internal.example -p 5433 -U postgres -d postgres -c "CREATE ROLE paperless LOGIN PASSWORD '<strong-password>';"
psql -h postgres.internal.example -p 5433 -U postgres -d postgres -c "CREATE DATABASE paperless OWNER paperless;"
```

## Validation goals

- `docker compose ps` shows `paperless` running.
- From NAS:
  - `curl -sS -m 6 -i http://127.0.0.1:8010/ | sed -n '1,8p'`
  returns an HTTP response.
- Container logs show successful DB/Redis connectivity and worker startup.

## Troubleshooting: HTTP 500 on login/startup

Symptom:

- Browser returns `500` from `paperless.internal.example`.
- Container logs show DB/Redis errors such as:
  - `Temporary failure in name resolution`
  - `Unable to connect after ... seconds`

Likely cause on Synology:

- `FORWARD_FIREWALL` / `INPUT_FIREWALL` drops Docker bridge traffic from
  `172.16.0.0/12`, preventing paperless network egress to LAN DNS/DB services.

Fix:

```bash
ssh nas-host 'bash -s' < ../ensure-docker-bridge-lan-egress.sh
```

Then redeploy/restart Paperless and re-check:

```bash
./deploy.sh nas-host
ssh nas-host "sudo -n /usr/local/bin/docker ps --format 'table {{.Names}}\t{{.Status}}' | grep nas-host-paperless"
```
