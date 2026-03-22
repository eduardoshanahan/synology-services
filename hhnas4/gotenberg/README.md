# Gotenberg (hhnas4)

Shared document conversion service for internal services on `hhnas4`.

## Purpose

- Provides one reusable Gotenberg endpoint for services in `internal.example`.
- Supports document conversion workflows (for example Paperless integrations).
- Keeps access internal-only (no DSM reverse proxy exposure).

## Service endpoint

- DNS name: `gotenberg.internal.example`
- Default port in this stack: `3001`

## DNS prerequisite

Create an internal DNS A record before switching clients:

- `gotenberg.internal.example -> <hhnas4-lan-ip>`

Quick check from a client:

```bash
getent hosts gotenberg.internal.example
```

## Layout

- `compose.yaml`
- `.env.example`
- sibling private `.env.sops` in `../synology-services-private/` (preferred tracked encrypted source)
- `deploy.sh`

## Runtime storage on NAS

Default target directory:

```text
/volume1/docker/homelab/hhnas4/gotenberg
```

This service is stateless in the default setup and does not require a Docker
data volume.

## Deploy

From this repository:

```bash
cd hhnas4/gotenberg
./deploy.sh hhnas4.internal.example
```

Optional target directory override:

```bash
./deploy.sh hhnas4.internal.example /volume1/docker/homelab/hhnas4/gotenberg
```

If you keep a sibling-private `.env.sops` (or a local fallback `.env` / `.env.sops` during transition), push it explicitly:

```bash
./deploy.sh hhnas4.internal.example --update-env
```

## First-start rules

- Keep this endpoint internal-only; do not expose it via DSM reverse proxy.
- Use HTTP from trusted internal clients, for example:
  - `http://gotenberg.internal.example:3001`

## Validation goals

- `docker compose ps` shows `gotenberg` running.
- From NAS:
  - `curl -sS -m 6 -i http://127.0.0.1:3001/health | sed -n '1,8p'`
  returns `HTTP/1.1 200 OK`.
- Client services can connect to the DNS endpoint and port.
