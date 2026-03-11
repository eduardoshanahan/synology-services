# nas-host Gitea Session Notes

Last updated: 2026-03-09

Purpose: capture operational findings from this session so future work can
resume without rediscovery.

## Current state

- Gitea is deployed on Synology host `nas-host` using:
  - compose path: `/volume1/docker/homelab/nas-host/gitea/compose.yaml`
  - env path: `/volume1/docker/homelab/nas-host/gitea/.env`
  - data path: `/volume1/docker/homelab/nas-host/gitea/data`
- Promtail is deployed on Synology host `nas-host` using:
  - compose path: `/volume1/docker/homelab/nas-host/promtail/compose.yaml`
  - env path: `/volume1/docker/homelab/nas-host/promtail/.env`
  - config path: `/volume1/docker/homelab/nas-host/promtail/config.yml`
- Public URL: `https://gitea.internal.example`
- SSH Git endpoint: `gitea.internal.example:2222`
- Container registry is enabled in Gitea.
- Gitea metrics endpoint is enabled and intended for Prometheus scrape.
- Gitea container logs are shipped by `promtail` with Loki job label
  `synology-gitea`.
- Admin user exists (username/email confirmed during this session).

## Key findings

- `scp` is not usable on this NAS (`subsystem request failed`), so deployment
  must support SSH stream copy.
- Docker is available at `/usr/local/bin/docker` (Container Manager path).
- Docker socket access may require `sudo`; non-interactive `sudo -n` works in
  current setup for compose operations.
- DSM reverse proxy must point `gitea.internal.example:443` to the correct NAS
  backend target on port `3000`; wrong destination yields `502`.
- Gitea internal SSH server must remain disabled in this setup:
  - `GITEA_SERVER_START_SSH_SERVER=false`
  - Reason: enabling it causes a bind conflict inside container (`:22`) and a
    restart loop.
- Git-over-SSH still works through the container port mapping
  (`2222 -> container 22`) because OpenSSH in the image handles SSH transport.

## Deploy script behavior (current)

`nas-host/gitea-deploy.sh` now:

- avoids `scp` and uses SSH stream copy for files,
- auto-detects docker binary path on target host,
- auto-selects docker privilege mode (`direct`, `sudo -n`, fallback `sudo`),
- preserves existing remote `.env` on redeploy,
- supports optional non-UI admin bootstrap:
  - `--admin-user`
  - `--admin-email`
  - `--admin-password`
- runs Gitea admin CLI as container user `git` (not root).
- no longer deploys `promtail`; use `nas-host/promtail-deploy.sh` for log shipping.

## Non-UI setup defaults

- SQLite is configured as default DB.
- Install wizard is locked by default:
  - `GITEA_SECURITY_INSTALL_LOCK=true`

## Health checks used in this session

- Backend from NAS:
  - `curl -sSI http://127.0.0.1:3000/`
- Public HTTPS:
  - `curl -skI https://gitea.internal.example/`
- SSH endpoint reachability:
  - `ssh -p 2222 -T git@gitea.internal.example`
  - Expected without key setup: `Permission denied (publickey)`

## Follow-ups

- Keep this file updated after each Gitea/Synology change.
- If deploy behavior changes, update both:
  - `nas-host/README.md`
  - this `SESSION_NOTES.md`
- Use `GITEA_OPERATIONS_CHECKLIST.md` as the post-deploy runbook.

## 2026-03-05 Outline + SMTP follow-up

- Outline is running on `nas-host` with shared infrastructure endpoints:
  - Postgres: `postgres.internal.example:5433`
  - Redis: `redis.internal.example:6379`
  - SMTP relay: `smtp-relay.internal.example:2525`
- Outline database password was rotated from the placeholder value to a strong
  random value generated with `openssl rand -hex ...`.
- Source-of-truth secret remains encrypted in:
  - `nas-host/outline/.env.sops`
- Runtime sync and DB role rotation were completed:
  - Outline env synced to NAS via `nas-host/outline/deploy.sh --update-env`
  - Postgres role updated with `ALTER ROLE outline WITH PASSWORD ...`
  - Authentication check with the rotated `outline` credentials succeeded.
- Outline startup/health behavior was validated after deploy:
  - container reports healthy
  - internal endpoint `/_health` returns `200` with expected proxy headers
  - public URL `https://outline.internal.example/` returns `HTTP/2 200`
- Current relay logs include confirmed `status=sent` for Gitea SMTP tests.
  Outline login flow is working; capture a fresh Outline-specific SMTP send log
  entry in a dedicated test for strict audit evidence.

## 2026-03-09 Shared Tika + Gotenberg deployment

- Apache Tika is deployed on `nas-host` using:
  - compose path: `/volume1/docker/homelab/nas-host/tika/compose.yaml`
  - env path: `/volume1/docker/homelab/nas-host/tika/.env`
  - container: `nas-host-tika`
  - endpoint: `http://<nas-host-lan-ip>:9998` (`/version` returns `Apache Tika 3.2.3`)
- Gotenberg is deployed on `nas-host` using:
  - compose path: `/volume1/docker/homelab/nas-host/gotenberg/compose.yaml`
  - env path: `/volume1/docker/homelab/nas-host/gotenberg/.env`
  - container: `nas-host-gotenberg`
  - endpoint: `http://<nas-host-lan-ip>:3001` (`/health` returns `HTTP 200` with
    `chromium` and `libreoffice` status `up`)
- DSM reverse proxy hostnames are now configured for operator access:
  - `https://tika.internal.example/version`
  - `https://gotenberg.internal.example/health`

## 2026-03-09 Paperless-ngx deployment

- Paperless-ngx is deployed on `nas-host` using:
  - compose path: `/volume1/docker/homelab/nas-host/paperless/compose.yaml`
  - env path: `/volume1/docker/homelab/nas-host/paperless/.env`
  - container: `nas-host-paperless`
  - local endpoint: `http://127.0.0.1:8010`
- Dependency wiring is active and validated from container logs:
  - Postgres: `postgres.internal.example:5433`
  - Redis: `redis.internal.example:6379`
  - Tika: `tika.internal.example:9998`
  - Gotenberg: `gotenberg.internal.example:3001`
- Runtime checks confirm successful startup:
  - migrations complete
  - Celery worker and beat started
  - HTTP `302` from `/` to login path
- Network note:
  - Paperless now runs on Docker network `paperless-net` with subnet
    `172.23.0.0/16` to avoid conflicting bridge ranges.
- Current Redis auth uses the shared Redis admin credential in
  `PAPERLESS_REDIS`. Plan a follow-up to introduce a dedicated Redis ACL user
  for Paperless and rotate to that account.
- DSM reverse proxy + certificate is configured for:
  - `https://paperless.internal.example/`
- A first admin user was bootstrapped:
  - username: `eduardo`
- Production incident observed and resolved:
  - Symptom: intermittent HTTP `500` on login.
  - Error in logs: `Temporary failure in name resolution` for Postgres/Redis.
  - Root cause: Synology firewall chain `FORWARD_FIREWALL` was dropping Docker
    bridge egress (`172.16.0.0/12`).
  - Remediation:
    - applied `nas-host/ensure-docker-bridge-lan-egress.sh` on host.
    - added `dns` to Paperless compose (`PAPERLESS_DNS`, default
      `192.0.2.10`) for deterministic internal DNS resolution.
  - Result: `nas-host-paperless` returned to `healthy`; login endpoint returns
    `HTTP 200`.

## 2026-03-10 Jellyfin discovery finding

- Jellyfin is running on `nas-host` at:
  - compose path: `/volume1/docker/homelab/nas-host/jellyfin/compose.yaml`
  - env path: `/volume1/docker/homelab/nas-host/jellyfin/.env`
  - container: `nas-host-jellyfin`
- Observed runtime before remediation:
  - container network mode: Docker bridge (`jellyfin_default`)
  - published ports: `127.0.0.1:8096->8096/tcp`
  - UDP discovery ports for Jellyfin local discovery / SSDP were not exposed
- User-visible symptom:
  - desktop and mobile clients worked through the configured URL
  - Google TV Streamer could not discover the server on LAN
- Likely root cause:
  - loopback-only bind plus missing UDP discovery ports prevented direct LAN
    discovery even though reverse-proxy access worked
- Tracked fix prepared in this repository:
  - `nas-host/jellyfin/compose.yaml` now exposes:
    - `8096/tcp`
    - `7359/udp`
  - `nas-host/jellyfin/.env.example` defaults `JELLYFIN_HOST_BIND=0.0.0.0`
- Additional deployment finding:
  - NAS host already has `0.0.0.0:1900/udp` in use, so publishing SSDP from the
    Jellyfin container fails on this Synology unless that host service is
    disabled or reconfigured
- Validation still needed after redeploy:
  - confirm direct LAN access to `http://<nas-host-lan-ip>:8096`
  - confirm DSM firewall allows `8096/tcp` and `7359/udp`
  - retest discovery from Google TV Streamer
