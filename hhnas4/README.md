# nas-host Synology Services

Reproducible, sanitized deployment artifacts for host `nas-host`.

## Included Stack

- `mysql` as shared MySQL server for internal services.
- `gitea` with built-in container registry enabled.
- `outline` for an internal wiki / knowledge base.
- `archivebox` for large local web archive storage.
- `postgres` as shared database server for internal services.
- `redis` as shared cache/queue backend for internal services.
- `mongo` as shared document database for internal services.
- `dolt` as shared versioned SQL database for internal services.
- `tika` as shared text and metadata extraction service for internal services.
- `gotenberg` as shared document conversion service for internal services.
- `paperless` document management with OCR using shared Postgres/Redis/Tika/Gotenberg.
- `karakeep` read-it-later/bookmarks service with dedicated NAS storage.
- `qbittorrent` torrent downloader with NAS-local config and a default
  downloads path under `/volume1/Media/Downloads/qbittorrent`.
- `woodpecker-agent` as the AMD64 Woodpecker CI runner.
- `jellyfin` media server with NAS-local config/cache, a configurable media
  mount, and bridge-mode LAN discovery ports exposed for TV clients.
- `promtail` shipping `gitea` and `jellyfin` container logs to Loki.
- `docker-socket-proxy` exposing a read-only Docker API for Homepage remote
  container status.

## Deploy

From this repository:

```bash
cd nas-host
./gitea-deploy.sh nas-host.internal.example
```

Optional target directory override:

```bash
./gitea-deploy.sh nas-host.internal.example /volume1/docker/homelab/nas-host
```

## Non-UI Bootstrap

Gitea is configured with SQLite and `INSTALL_LOCK=true` by default, so you can
bootstrap without opening the install wizard.

Create (or ensure) an admin user at deploy time:

```bash
./gitea-deploy.sh nas-host.internal.example \
  --admin-user gitea-admin \
  --admin-email admin@example.com \
  --admin-password 'change-me-now'
```

If the admin user already exists, the script keeps it and continues.

## Authentik OIDC For Gitea

`gitea-deploy.sh` can declaratively create/update a Gitea OAuth2 login source
for Authentik.

Set these keys in `gitea/.env` on NAS:

- `GITEA_AUTHENTIK_OIDC_ENABLED=true`
- `GITEA_AUTHENTIK_OIDC_NAME=authentik`
- `GITEA_AUTHENTIK_OIDC_DISCOVERY_URL=https://authentik.<domain>/application/o/gitea/.well-known/openid-configuration`
- `GITEA_AUTHENTIK_OIDC_CLIENT_ID=<client-id>`
- `GITEA_AUTHENTIK_OIDC_CLIENT_SECRET=<client-secret>`
- Optional group mapping:
  - `GITEA_AUTHENTIK_OIDC_GROUP_CLAIM_NAME=groups`
  - `GITEA_AUTHENTIK_OIDC_ADMIN_GROUP=<group-name>`
  - `GITEA_AUTHENTIK_OIDC_RESTRICTED_GROUP=<group-name>`

Use this redirect URI in Authentik:

`https://gitea.<domain>/user/oauth2/authentik/callback`

## Additional Deploy Entrypoints

- Promtail:

```bash
./promtail-deploy.sh nas-host.internal.example
```

- Docker socket proxy:

```bash
./docker-socket-proxy/deploy.sh nas-host.internal.example
```

- Woodpecker agent:

```bash
./woodpecker-agent/deploy.sh nas-host.internal.example
```

- Jellyfin:

```bash
./jellyfin/deploy.sh nas-host.internal.example
```

- qBittorrent:

```bash
./qbittorrent/deploy.sh nas-host.internal.example
```

## Shared Infra Backups

Centralized backup orchestration for shared Postgres/MySQL/Redis state:

```bash
./backup-shared-infra.sh nas-host
```

The full workflow lives in
`SHARED_INFRA_BACKUP_RUNBOOK.md`.

## Documentation Map

- Host-local docs index:
  - `DOCUMENTATION_INDEX.md`
- Session continuity notes:
  - `SESSION_NOTES.md`
- Host runbooks and checklists:
  - `GITEA_OPERATIONS_CHECKLIST.md`
  - `DOCKER_ADDRESS_POOL_RUNBOOK.md`
  - `SHARED_INFRA_BACKUP_RUNBOOK.md`
  - `GITEA_NAS_PLACEMENT_AND_BRIDGE_EGRESS_FIX_2026-03-05.md`

## Notes

- The copied `.env` is a template; adjust values on NAS as needed.
- No credentials or secret values are committed in this directory.
- Future bridge-mode services on `nas-host` should be planned around a reserved
  Docker address pool on the NAS.
- `smtp-relay/` is currently an intentional placeholder only; there is no live
  Synology SMTP relay stack in this repository today.

Longer operational guidance now lives in
`DOCUMENTATION_INDEX.md`
instead of expanding this README into a runbook.

## Registry Behavior

Container registry is enabled through Gitea settings in compose env vars:

- `GITEA__packages__ENABLED=true`
- `GITEA__packages__CONTAINER__ENABLED=true`

Set `GITEA_REGISTRY_HOST` and `GITEA_REGISTRY_EXTERNAL_URL` in `.env` to the
host/domain clients will use for pushes and pulls.

Example image path:

```text
<registry-host>/<owner>/<image>:<tag>
```
