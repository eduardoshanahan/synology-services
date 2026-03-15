# Jellyfin (nas-host)

Media server stack for `nas-host` with bridge networking and LAN discovery
enabled for direct TV clients.

## Purpose

- Runs Jellyfin directly on the Synology host.
- Keeps Jellyfin config and cache local to the NAS.
- Exposes the app port and Jellyfin local discovery on the LAN without using
  `network_mode: host`.
- Preserves DSM reverse-proxy access for browser/mobile clients.
- Leaves hardware acceleration disabled by default; add device mappings only after validating the host can support them.

## Service endpoint

- DNS name: `jellyfin.internal.example`
- Default app port in this stack: `8096`
- Discovery ports:
  - Jellyfin local discovery: `7359/udp`

## Runtime storage on NAS

Default target directory:

```text
/volume1/docker/homelab/nas-host/jellyfin
```

Bind-mounted paths:

```text
config/
cache/
```

Default media path exposed read-only inside the container:

```text
/volume1/Media
```

## Layout

- `compose.yaml`
- `.env.sops` (recommended tracked encrypted source)
- `.env.example`
- `deploy.sh`

## Deploy

From this repository:

```bash
cd nas-host/jellyfin
./deploy.sh nas-host.internal.example
```

Optional target directory override:

```bash
./deploy.sh nas-host.internal.example /volume1/docker/homelab/nas-host/jellyfin
```

If you keep local `.env` (or encrypted `.env.sops`), push it explicitly:

```bash
./deploy.sh nas-host.internal.example --update-env
```

## First-start rules

- Set `JELLYFIN_MEDIA_DIR` in `.env` to a real media path on `nas-host` before
  the first deploy.
- Keep `JELLYFIN_HOST_BIND=0.0.0.0`; `127.0.0.1` prevents direct LAN clients
  from reaching the app port.
- Keep `JELLYFIN_PUBLISHED_SERVER_URL=https://jellyfin.internal.example`
  aligned with the client URL.
- Keep UDP `7359` published if client autodiscovery is required.
- `1900/udp` is not published by default because Synology commonly already uses
  SSDP on the host. If you later free that port on the NAS, you can add it
  back for broader DLNA-style discovery.
- Ensure the media path is readable by the container runtime user on Synology; if library scans fail, fix NAS ACLs before changing Jellyfin itself.
- If metadata searches are empty and logs show DNS or `TheMovieDb` errors, re-run `/volume1/docker/homelab/nas-host/ensure-docker-bridge-lan-egress.sh` on the NAS and verify Docker bridge subnets are allowed through Synology firewall chains.
- If DSM firewall is enabled, allow inbound LAN access to:
  - `8096/tcp`
  - `7359/udp`
- If a router or access point has guest isolation or AP isolation enabled,
  discovery can still fail even when the container is configured correctly.
- Promtail on `nas-host` is configured to ship Jellyfin container logs to Loki under job label `synology-jellyfin`.

## Reverse Proxy (DSM)

Recommended public shape:

- Client URL: `https://jellyfin.internal.example/`
- DSM reverse proxy backend: `http://<nas-host-lan-ip>:8096`

Keep TLS termination in DSM. Jellyfin itself should continue serving plain HTTP
on the LAN endpoint.

## Validation goals

- `docker compose ps` shows `nas-host-jellyfin` running.
- From NAS:
  - `curl -sS -m 6 -i http://127.0.0.1:8096 | sed -n '1,12p'`
  returns an HTTP response.
- On a LAN client, manual connection to `http://<nas-host-lan-ip>:8096` works.
- TV/streaming clients can discover the server after UDP `7359` is opened.
- Through the reverse proxy:
  - `curl -skI https://jellyfin.internal.example/ | sed -n '1,12p'`
  returns an HTTP response.
- In Grafana Explore (Loki), `{job="synology-jellyfin"}` returns recent container logs after startup.
