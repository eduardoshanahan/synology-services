# Apache Tika (nas-host)

Shared text and metadata extraction service for internal services on `nas-host`.

## Purpose

- Provides one reusable Tika endpoint for services in `internal.example`.
- Supports extraction workflows (for example Paperless integrations).
- Keeps access internal-only (no DSM reverse proxy exposure).

## Service endpoint

- DNS name: `tika.internal.example`
- Default port in this stack: `9998`

## DNS prerequisite

Create an internal DNS A record before switching clients:

- `tika.internal.example -> <nas-host-lan-ip>`

Quick check from a client:

```bash
getent hosts tika.internal.example
```

## Layout

- `compose.yaml`
- `.env.example`
- sibling private `.env.sops` in `../synology-services-private/` (preferred tracked encrypted source)
- `deploy.sh`

## Runtime storage on NAS

Default target directory:

```text
/volume1/docker/homelab/nas-host/tika
```

This service is stateless in the default setup and does not require a Docker
data volume.

## Deploy

From this repository:

```bash
cd nas-host/tika
./deploy.sh nas-host.internal.example
```

Optional target directory override:

```bash
./deploy.sh nas-host.internal.example /volume1/docker/homelab/nas-host/tika
```

If you keep a sibling-private `.env.sops` (or a local fallback `.env` / `.env.sops` during transition), push it explicitly:

```bash
./deploy.sh nas-host.internal.example --update-env
```

## First-start rules

- Keep this endpoint internal-only; do not expose it via DSM reverse proxy.
- Use HTTP from trusted internal clients, for example:
  - `http://tika.internal.example:9998`

## Validation goals

- `docker compose ps` shows `tika` running.
- From NAS:
  - `curl -sS -m 6 -i http://127.0.0.1:9998/version | sed -n '1,8p'`
  returns `HTTP/1.1 200 OK` and a version string.
- Client services can connect to the DNS endpoint and port.
