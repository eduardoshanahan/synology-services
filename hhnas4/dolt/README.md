# Dolt (nas-host)

Shared Dolt SQL server for internal services on `nas-host`.

## Purpose

- Provides one reusable Dolt SQL endpoint for services in `internal.example`.
- Keeps versioned database state local on NAS with Docker-managed persistent storage.
- Exposes Prometheus metrics for Grafana / Prometheus integration.
- Keeps access internal-only; do not expose it through DSM reverse proxy.

## Service endpoints

- SQL endpoint: `dolt.internal.example`
- Default SQL port in this stack: `3307`
- Metrics endpoint: `http://dolt.internal.example:11228/metrics`

The stack uses `3307` instead of `3306` to avoid clashing with the shared
MySQL service already running on `nas-host`.

## DNS prerequisite

Create an internal DNS A record before switching clients:

- `dolt.internal.example -> <nas-host-lan-ip>`

Quick checks from a client:

```bash
getent hosts dolt.internal.example
curl -sS http://dolt.internal.example:11228/metrics | sed -n '1,20p'
```

## Layout

- `compose.yaml`
- `.env.example`
- `.env.sops` (recommended tracked encrypted source)
- `deploy.sh`
- `server/config.yaml`

## Runtime storage on NAS

Default target directory:

```text
/volume1/docker/homelab/nas-host/dolt
```

Docker-managed persistent volume:

```text
dolt_data
```

Inside the container, Dolt stores versioned databases and config under:

```text
/var/lib/dolt
```

## Deploy

From this repository:

```bash
cd nas-host/dolt
./deploy.sh nas-host.internal.example
```

Optional target directory override:

```bash
./deploy.sh nas-host.internal.example /volume1/docker/homelab/nas-host/dolt
```

If you keep local `.env` (or encrypted `.env.sops`), push it explicitly:

```bash
./deploy.sh nas-host.internal.example --update-env
```

## First-start rules

- Set a strong `DOLT_ROOT_PASSWORD` before first production start.
- Keep `DOLT_ROOT_HOST=%` only if you need LAN clients to connect as `root`.
- Prefer one SQL user per application instead of sharing `root`.
- Keep the SQL and metrics endpoints internal-only.

Example bootstrap from a client:

```bash
mysql -h dolt.internal.example -P 3307 -u root -p
CREATE DATABASE app_db;
CREATE USER 'app_user'@'%' IDENTIFIED BY '<strong-password>';
GRANT ALL PRIVILEGES ON app_db.* TO 'app_user'@'%';
FLUSH PRIVILEGES;
```

## Validation goals

- `docker compose ps` shows `dolt` healthy.
- SQL clients can connect to `dolt.internal.example:3307`.
- `curl http://dolt.internal.example:11228/metrics` exposes `dss_` metrics.

## Storage and backup note

- Dolt persists full database history, so disk usage grows with both current data
  and retained commit history.
- Prefer periodic volume-level backups on NAS plus regular restore drills.
- If history grows aggressively, plan explicit garbage-collection windows because
  GC can be CPU- and memory-intensive.
