# Solidtime (nas-host)

Self-hosted Solidtime stack for `nas-host`.

> Status: deprecated for active deployment after the Pi pivot.
> Keep this directory as historical reference only.

## Purpose

- Runs Solidtime behind the Synology DSM reverse proxy.
- Uses shared PostgreSQL endpoint `postgres.internal.example:5433` with a
  dedicated Solidtime database/user/schema.
- Follows the same deploy pattern as other `nas-host` stacks.

## Layout

- `compose.yaml`
- `.env.example`
- `laravel.env.example`
- `deploy.sh`

## Runtime storage on NAS

Default target directory:

```text
/volume1/docker/homelab/nas-host/solidtime
```

Docker-managed persistent volumes:

```text
solidtime_app_storage
```

Local bind-mounted runtime paths inside target dir:

```text
logs/
app-storage/
```

## Deploy

From this repository:

```bash
cd nas-host/solidtime
./deploy.sh nas-host.internal.example
```

Optional target directory override:

```bash
./deploy.sh nas-host.internal.example /volume1/docker/homelab/nas-host/solidtime
```

If you keep local `.env` and/or `laravel.env` (or encrypted `.env.sops` / `laravel.env.sops`), push them explicitly:

```bash
./deploy.sh nas-host.internal.example --update-env
```

## First-start rules

- Keep this stack behind DSM reverse proxy.
- Default host-loopback ports:
  - Solidtime app: `127.0.0.1:3800`
- Local shared PostgreSQL proxy listener: `172.17.0.1:15434` (Docker bridge gateway)
- `deploy.sh` automatically fixes ownership on `logs/` and `app-storage/` for
  Solidtime's runtime user (`uid:gid 1000:1000`).
- Set DB settings in `laravel.env` for the dedicated Solidtime DB/user created
  on shared PostgreSQL:
  - `DB_HOST=host.docker.internal`
  - `DB_PORT=15434`
- Stack includes `shared-pg-proxy` sidecar that forwards to
  `127.0.0.1:5433` (shared PostgreSQL on the NAS host). This keeps Solidtime
  decoupled from Outline while staying compatible with Synology bridge
  networking limits.
- Set `APP_URL` in `laravel.env` to the final public HTTPS URL.
- Generate required app keys once, then copy values into `laravel.env`:

```bash
docker compose run --rm scheduler php artisan self-host:generate-keys
```

- After updating keys in `laravel.env`, restart the stack:

```bash
docker compose up -d
```

- Run migrations explicitly from the scheduler container:

```bash
docker compose exec scheduler php artisan migrate --force
```

- Provision fresh DB/user/schema in shared PostgreSQL before first migration:

```bash
sudo docker exec nas-host-postgres psql -U postgres -d postgres -c "CREATE ROLE solidtime LOGIN PASSWORD '<new-password>';"
sudo docker exec nas-host-postgres psql -U postgres -d postgres -c "CREATE DATABASE solidtime OWNER solidtime;"
sudo docker exec nas-host-postgres psql -U postgres -d solidtime -c "CREATE SCHEMA IF NOT EXISTS solidtime AUTHORIZATION solidtime;"
sudo docker exec nas-host-postgres psql -U postgres -d postgres -c "ALTER ROLE solidtime IN DATABASE solidtime SET search_path TO solidtime,public;"
```

## Reverse Proxy (DSM)

Recommended public shape:

- Client URL: `https://solidtime.internal.example/`
- DSM reverse proxy backend: `http://127.0.0.1:3800`

Keep TLS termination in DSM. Solidtime should continue serving HTTP on loopback only.

## Validation goals

- `docker compose ps` shows healthy `app`, `scheduler`, `queue`,
  `shared-pg-proxy`, `gotenberg`.
- `curl -sSI http://127.0.0.1:3800/` returns a page or redirect from the NAS.
- `curl -skI https://solidtime.internal.example/` returns a page or redirect through DSM.
- First admin user can be created via:

```bash
docker compose exec scheduler php artisan admin:user:create "Your Name" "you@example.com" --verify-email
```

## Backup note

- Shared PostgreSQL stores Solidtime DB state; include it in DB backups.
- Include app storage volume (`solidtime_app_storage`) and `app-storage/` in backups.
- Keep `laravel.env` backed up securely; it contains cryptographic keys required for the instance.
