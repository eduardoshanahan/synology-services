# hhnas4 Gitea Session Notes

Last updated: 2026-03-09

Purpose: capture operational findings from this session so future work can
resume without rediscovery.

## Current state

- Gitea is deployed on Synology host `hhnas4` using:
  - compose path: `/volume1/docker/homelab/hhnas4/gitea/compose.yaml`
  - env path: `/volume1/docker/homelab/hhnas4/gitea/.env`
  - data path: `/volume1/docker/homelab/hhnas4/gitea/data`
- Promtail is deployed on Synology host `hhnas4` using:
  - compose path: `/volume1/docker/homelab/hhnas4/promtail/compose.yaml`
  - env path: `/volume1/docker/homelab/hhnas4/promtail/.env`
  - config path: `/volume1/docker/homelab/hhnas4/promtail/config.yml`
- Adminer is deployed on Synology host `hhnas4` using:
  - compose path: `/volume1/docker/homelab/hhnas4/adminer/compose.yaml`
  - env path: `/volume1/docker/homelab/hhnas4/adminer/.env`
  - container: `hhnas4-adminer`
  - internal endpoint: `http://adminer.internal.example:8070` (fronted via DSM
    reverse proxy for HTTPS)
  - Docker network: the shared database bridge so the UI can reach the shared MySQL,
    MariaDB, PostgreSQL, and Dolt services without publishing new bridges.
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

`hhnas4/gitea-deploy.sh` now:

- avoids `scp` and uses SSH stream copy for files,
- auto-detects docker binary path on target host,
- auto-selects docker privilege mode (`direct`, `sudo -n`, fallback `sudo`),
- preserves existing remote `.env` on redeploy,
- supports optional non-UI admin bootstrap:
  - `--admin-user`
  - `--admin-email`
  - `--admin-password`
- runs Gitea admin CLI as container user `git` (not root).
- no longer deploys `promtail`; use `hhnas4/promtail-deploy.sh` for log shipping.

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
  - `hhnas4/README.md`
  - this `SESSION_NOTES.md`
- Use `GITEA_OPERATIONS_CHECKLIST.md` in this `docs/` directory as the
  post-deploy runbook.

## 2026-03-05 Outline + SMTP follow-up

- Outline is running on `hhnas4` with shared infrastructure endpoints:
  - Postgres: `postgres.internal.example:5433`
  - Redis: `redis.internal.example:6379`
  - SMTP relay: `smtp-relay.internal.example:2525`
- Outline database password was rotated from the placeholder value to a strong
  random value generated with `openssl rand -hex ...`.
- Source-of-truth secret remains encrypted in:
  - `../synology-services-private/hhnas4/outline/.env.sops`
- Runtime sync and DB role rotation were completed:
  - Outline env synced to NAS via `hhnas4/outline/deploy.sh --update-env`
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

- Apache Tika is deployed on `hhnas4` using:
  - compose path: `/volume1/docker/homelab/hhnas4/tika/compose.yaml`
  - env path: `/volume1/docker/homelab/hhnas4/tika/.env`
  - container: `hhnas4-tika`
  - endpoint: `http://<hhnas4-lan-ip>:9998` (`/version` returns `Apache Tika 3.2.3`)
- Gotenberg is deployed on `hhnas4` using:
  - compose path: `/volume1/docker/homelab/hhnas4/gotenberg/compose.yaml`
  - env path: `/volume1/docker/homelab/hhnas4/gotenberg/.env`
  - container: `hhnas4-gotenberg`
  - endpoint: `http://<hhnas4-lan-ip>:3001` (`/health` returns `HTTP 200` with
    `chromium` and `libreoffice` status `up`)
- DSM reverse proxy hostnames are now configured for operator access:
  - `https://tika.internal.example/version`
  - `https://gotenberg.internal.example/health`

## 2026-03-09 Paperless-ngx deployment

- Paperless-ngx is deployed on `hhnas4` using:
  - compose path: `/volume1/docker/homelab/hhnas4/paperless/compose.yaml`
  - env path: `/volume1/docker/homelab/hhnas4/paperless/.env`
  - container: `hhnas4-paperless`
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
  - username: `<bootstrap-admin>`
- Production incident observed and resolved:
  - Symptom: intermittent HTTP `500` on login.
  - Error in logs: `Temporary failure in name resolution` for Postgres/Redis.
  - Root cause: Synology firewall chain `FORWARD_FIREWALL` was dropping Docker
    bridge egress (`172.16.0.0/12`).
  - Remediation:
    - applied `hhnas4/ensure-docker-bridge-lan-egress.sh` on host.
    - added `dns` to Paperless compose (`PAPERLESS_DNS`, default
      `<dns-lan-ip>`) for deterministic internal DNS resolution.
  - Result: `hhnas4-paperless` returned to `healthy`; login endpoint returns
    `HTTP 200`.

## 2026-03-10 Jellyfin discovery finding

- Jellyfin is running on `hhnas4` at:
  - compose path: `/volume1/docker/homelab/hhnas4/jellyfin/compose.yaml`
  - env path: `/volume1/docker/homelab/hhnas4/jellyfin/.env`
  - container: `hhnas4-jellyfin`
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
  - `hhnas4/jellyfin/compose.yaml` now exposes:
    - `8096/tcp`
    - `7359/udp`
  - `hhnas4/jellyfin/.env.example` defaults `JELLYFIN_HOST_BIND=0.0.0.0`
- Additional deployment finding:
  - NAS host already has `0.0.0.0:1900/udp` in use, so publishing SSDP from the
    Jellyfin container fails on this Synology unless that host service is
    disabled or reconfigured
- Validation still needed after redeploy:
  - confirm direct LAN access to `http://<hhnas4-lan-ip>:8096`
  - confirm DSM firewall allows `8096/tcp` and `7359/udp`
  - retest discovery from Google TV Streamer

## 2026-03-22 Outline publish/offline incident

- User-visible symptoms:
  - Outline web UI loaded, but editing showed `offline`.
  - Publish attempts failed with `Couldn't publish the document, please try again`.
- Live checks on `2026-03-22` showed:
  - `https://outline.internal.example/` returned `HTTP/2 200`
  - Outline container was `healthy`
  - local storage inside `/var/lib/outline/data` was writable
  - shared Postgres and Redis containers were both `healthy`
- Primary root cause found in Outline logs:
  - Redis ACL denied `KEYS` for the `outline` user:
    `NOPERM User outline has no permissions to run the 'keys' command`
  - the shared Redis ACL had been defined as `+@all -@admin -@dangerous`,
    which removes `KEYS`
- Repo fix:
  - `hhnas4/redis/compose.yaml` now re-allows `+keys` for the Outline Redis
    user while still keeping `-@admin -@dangerous`
- Additional note:
  - Outline logs also contained earlier transient `ECONNREFUSED
    <nas-lan-ip>:5433` errors for Postgres, but Postgres was healthy during the
    incident review and the persistent user-facing failure aligned with the
    Redis ACL denial.
- Later the same day, after the Redis ACL recovery:
  - Outline regressed to `502` after restarts and the UI again behaved
    inconsistently
  - earlier app logs had shown intermittent `ENOTFOUND
    postgres.<domain>` / `redis.<domain>` during recovery
  - the Synology Docker daemon config on `hhnas4` had the reserved address
    pool configured but no explicit daemon `dns` setting
- Permanent host-level fix applied on `2026-03-22`:
  - updated `/var/packages/ContainerManager/etc/dockerd.json` on `hhnas4` to
    keep:
    - `bip: 10.254.0.1/24`
    - `default-address-pools: 10.253.0.0/16 size 24`
  - and add:
    - `dns: [<primary-lan-dns-ip>, <secondary-lan-dns-ip>]`
  - restarted `pkg-ContainerManager-dockerd.service`
  - recreated the Outline container so it picked up the new daemon DNS policy
- Validation after host-level fix:
  - `docker info` still reported the reserved `10.253.0.0/16` address pool
  - Outline container returned to `healthy`
  - `https://outline.internal.example/` returned `HTTP/2 200`
  - `https://outline.internal.example/realtime/?EIO=4&transport=polling`
    returned a Socket.IO handshake payload
- Follow-up finding later the same evening:
  - the UI still showed `offline` even after a hard refresh
  - local collaboration websocket handling inside Outline was healthy:
    - direct `ws://127.0.0.1:3010/collaboration/<document-id>` upgraded
  - public collaboration websocket handling through DSM reverse proxy was not:
    - `https://outline.internal.example/collaboration/<document-id>` returned
      `HTTP/1.1 200 OK` and the normal Outline HTML shell instead of websocket
      `101 Switching Protocols`
  - this isolates the remaining issue to DSM reverse proxy websocket handling
    for Outline collaboration paths, not app health, Redis, Postgres, or DNS
- Final reverse proxy fix:
  - enabling websocket forwarding on the DSM reverse proxy entry for Outline
    restored document collaboration
  - after that change, the public collaboration path returned websocket
    `101 Switching Protocols` instead of the HTML shell fallback
- Operational note:
  - Docker containers still showed `nameserver 127.0.0.11` in
    `/etc/resolv.conf`; this was expected
  - the daemon `dns` change controls the upstream resolvers used by Docker's
    embedded resolver, not the literal resolver line written into every
    container
- Private follow-up:
  - exact resolver values, live hostname details, and operator-specific sudo
    workflow were moved to the private companion repo for continuity without
    publishing host-internal identifiers
