# Jellyfin (hhnas4)

Media server stack for `hhnas4`.

## Purpose

- Runs Jellyfin directly on the Synology host.
- Keeps Jellyfin config and cache local to the NAS.
- Publishes only on host loopback by default and expects DSM reverse proxy in front.
- Leaves hardware acceleration disabled by default; add device mappings only after validating the host can support them.

## Service endpoint

- DNS name: `jellyfin.internal.example`
- Default app port in this stack: `8096`

## Layout

- `compose.yaml`
- `.env.example`
- `deploy.sh`

## Runtime storage on NAS

Default target directory:

```text
/volume1/docker/homelab/hhnas4/jellyfin
```

Bind-mounted runtime paths:

```text
config/
cache/
```

Required media bind mount (set in `.env`):

```text
JELLYFIN_MEDIA_DIR=/volume1/media
```

## Deploy

From this repository:

```bash
cd hhnas4/jellyfin
./deploy.sh hhnas4.internal.example
```

Optional target directory override:

```bash
./deploy.sh hhnas4.internal.example /volume1/docker/homelab/hhnas4/jellyfin
```

If you keep local `.env` (or encrypted `.env.sops`), push it explicitly:

```bash
./deploy.sh hhnas4.internal.example --update-env
```

## First-start rules

- Set `JELLYFIN_MEDIA_DIR` in `.env` to a real media path on `hhnas4` before the first deploy.
- Keep `JELLYFIN_HOST_BIND=127.0.0.1` when using the DSM reverse proxy.
- Keep `JELLYFIN_PUBLISHED_SERVER_URL=https://jellyfin.internal.example` aligned with the client URL.
- Ensure the media path is readable by the container runtime user on Synology; if library scans fail, fix NAS ACLs before changing Jellyfin itself.
- If metadata searches are empty and logs show DNS or `TheMovieDb` errors, re-run `/volume1/docker/homelab/hhnas4/ensure-docker-bridge-lan-egress.sh` on the NAS and verify Docker bridge subnets are allowed through Synology firewall chains.
- This layout is HTTP-on-loopback only. DLNA and raw LAN discovery are intentionally not enabled here.
- Promtail on `hhnas4` is configured to ship Jellyfin container logs to Loki under job label `synology-jellyfin`.

## Reverse Proxy (DSM)

Recommended public shape:

- Client URL: `https://jellyfin.internal.example/`
- DSM reverse proxy backend: `http://127.0.0.1:8096`

Keep TLS termination in DSM. Jellyfin itself should continue serving plain HTTP on loopback only.

## Validation goals

- `docker compose ps` shows `hhnas4-jellyfin` running.
- From NAS:
  - `curl -sS -m 6 -I http://127.0.0.1:8096/ | sed -n '1,12p'`
  returns an HTTP response.
- Through the reverse proxy:
  - `curl -skI https://jellyfin.internal.example/ | sed -n '1,12p'`
  returns an HTTP response.
- In Grafana Explore (Loki), `{job="synology-jellyfin"}` returns recent container logs after startup.
