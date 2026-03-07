# Docker Socket Proxy (hhnas4)

Read-only Docker API proxy for remote Homepage container status cards.

## Purpose

- Exposes a constrained Docker API endpoint from `hhnas4`.
- Prevents direct raw socket access from remote consumers.
- Keeps write/mutating API paths disabled by default.

## Layout

- `compose.yaml`
- `.env.example`
- `deploy.sh`

## Runtime storage on NAS

Default target directory:

```text
/volume1/docker/homelab/hhnas4/docker-socket-proxy
```

## Deploy

From this repository:

```bash
cd hhnas4/docker-socket-proxy
./deploy.sh hhnas4.internal.example
```

Optional target directory override:

```bash
./deploy.sh hhnas4.internal.example /volume1/docker/homelab/hhnas4/docker-socket-proxy
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
