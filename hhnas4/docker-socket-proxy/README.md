# Docker Socket Proxy (nas-host)

Read-only Docker API proxy for remote Homepage container status cards.

## Purpose

- Exposes a constrained Docker API endpoint from `nas-host`.
- Prevents direct raw socket access from remote consumers.
- Keeps write/mutating API paths disabled by default.

## Layout

- `compose.yaml`
- `.env.example`
- `deploy.sh`

## Runtime storage on NAS

Default target directory:

```text
/volume1/docker/homelab/nas-host/docker-socket-proxy
```

## Deploy

From this repository:

```bash
cd nas-host/docker-socket-proxy
./deploy.sh nas-host.internal.example
```

Optional target directory override:

```bash
./deploy.sh nas-host.internal.example /volume1/docker/homelab/nas-host/docker-socket-proxy
```

## First-start rules

- Keep `PROXY_BIND_ADDRESS` restricted (for example `127.0.0.1`) unless you
  explicitly need LAN exposure.
- Keep `PROXY_PORT` aligned with the consumer configuration.
- The compose image is pinned by digest for reproducibility.

## Validation goals

- Container is healthy and running.
- TCP endpoint answers on configured bind/port.
- Read-only Docker API calls succeed (for example `/_ping`, `/containers/json`).
- Mutating API calls remain blocked.
