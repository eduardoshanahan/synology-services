# `hhnas4` Documentation Index

Canonical map for host-level documentation under `synology-services/hhnas4/docs/`.

## Core Docs

- Host overview and deploy entrypoint:
  - `../README.md`
- Session continuity notes:
  - `SESSION_NOTES.md`

## Runbooks And Checklists

- Post-deploy Gitea operations:
  - `GITEA_OPERATIONS_CHECKLIST.md`
- Docker address pool migration and firewall planning:
  - `DOCKER_ADDRESS_POOL_RUNBOOK.md`
- Shared infra backup workflow:
  - `SHARED_INFRA_BACKUP_RUNBOOK.md`
- Historical Gitea placement and bridge egress investigation:
  - `GITEA_NAS_PLACEMENT_AND_BRIDGE_EGRESS_FIX_2026-03-05.md`

## Stack READMEs

- Shared infra:
  - `../mysql/README.md`
  - `../postgres/README.md`
  - `../redis/README.md`
  - `../mongo/README.md`
  - `../dolt/README.md`
  - `../tika/README.md`
  - `../gotenberg/README.md`
- Applications:
  - `../gitea/README.md`
  - `../outline/README.md`
  - `../paperless/README.md`
  - `../karakeep/README.md`
  - `../jellyfin/README.md`
  - `../qbittorrent/README.md`
  - `../archivebox/README.md`
- Observability and integration:
  - `../promtail/README.md`
  - `../docker-socket-proxy/README.md`
  - `../woodpecker-agent/README.md`

## Operational Notes

- Long-term bridge-network planning, current exceptions, and migration details
  live in `DOCKER_ADDRESS_POOL_RUNBOOK.md`.
- Promtail settings live at `promtail/.env` on the NAS. Set `LOKI_PUSH_URL` to
  your Loki endpoint, for example
  `http://loki.<domain>:3100/loki/api/v1/push`.

## Current Placeholders

- `smtp-relay/` is intentionally a placeholder only today:
  - `../smtp-relay/README.md`

## Boundary Reminder

- `../../README.md`
  - repo overview, scope, and top-level documentation pointers
- `../README.md`
  - host overview and deploy entrypoints
- `SESSION_NOTES.md`
  - host-specific continuity notes across sessions
