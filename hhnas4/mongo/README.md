# MongoDB (nas-host)

Shared MongoDB server for internal services on `nas-host`.

## Purpose

- Provides one reusable MongoDB endpoint for services in `internal.example`.
- Keeps data local on NAS with Docker-managed persistent storage.
- Keeps access internal-only (no DSM reverse proxy exposure).

## Service endpoint

- DNS name: `mongo.internal.example`
- Default port in this stack: `27017`

## DNS prerequisite

Create an internal DNS A record before switching clients:

- `mongo.internal.example -> <nas-host-lan-ip>`

Quick check from a client:

```bash
getent hosts mongo.internal.example
```

## Layout

- `compose.yaml`
- `.env.example`
- sibling private `.env.sops` in `../synology-services-private/` (preferred tracked encrypted source)
- `deploy.sh`

## Runtime storage on NAS

Default target directory:

```text
/volume1/docker/homelab/nas-host/mongo
```

Docker-managed persistent volume:

```text
mongo_data
```

## Deploy

From this repository:

```bash
cd nas-host/mongo
./deploy.sh nas-host.internal.example
```

Optional target directory override:

```bash
./deploy.sh nas-host.internal.example /volume1/docker/homelab/nas-host/mongo
```

If you keep a sibling-private `.env.sops` (or a local fallback `.env` / `.env.sops` during transition), push it explicitly:

```bash
./deploy.sh nas-host.internal.example --update-env
```

## First-start rules

- Set strong credentials in `.env` before production use:
  - `MONGO_INITDB_ROOT_USERNAME`
  - `MONGO_INITDB_ROOT_PASSWORD`
- Keep this endpoint internal-only; do not expose it via DSM reverse proxy.
- Use authenticated connection strings from clients, for example:
  - `mongodb://<user>:<password>@mongo.internal.example:27017/?authSource=admin`

## Validation goals

- `docker compose ps` shows `mongo` healthy.
- From NAS:
  - `mongosh "mongodb://<user>:<password>@127.0.0.1:27017/?authSource=admin" --quiet --eval 'db.adminCommand({ ping: 1 })'`
  returns `{ ok: 1 }`.
- Client services can connect using DNS endpoint and auth.
