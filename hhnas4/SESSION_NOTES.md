# hhnas4 Gitea Session Notes

Last updated: 2026-02-25

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
- Use `GITEA_OPERATIONS_CHECKLIST.md` as the post-deploy runbook.
