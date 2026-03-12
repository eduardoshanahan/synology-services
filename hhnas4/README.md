# nas-host Synology Services

Reproducible, sanitized deployment artifacts for host `nas-host`.

## Included stack

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

## Non-UI bootstrap (recommended)

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

## Promtail

Deploy log shipping separately:

```bash
./promtail-deploy.sh nas-host.internal.example
```

Optional target directory override:

```bash
./promtail-deploy.sh nas-host.internal.example /volume1/docker/homelab/nas-host
```

## Docker socket proxy (Homepage remote container stats)

Deploy separately:

```bash
./docker-socket-proxy/deploy.sh nas-host.internal.example
```

## Woodpecker Agent

Deploy separately:

```bash
./woodpecker-agent/deploy.sh nas-host.internal.example
```

## Jellyfin

Deploy separately:

```bash
./jellyfin/deploy.sh nas-host.internal.example
```

## qBittorrent

Deploy separately:

```bash
./qbittorrent/deploy.sh nas-host.internal.example
```

## Shared Infra Backups

Centralized backup orchestration for shared Postgres/MySQL/Redis state:

```bash
./backup-shared-infra.sh nas-host
```

Runbook:

- `SHARED_INFRA_BACKUP_RUNBOOK.md`

## Registry behavior

Container registry is enabled through Gitea settings in compose env vars:

- `GITEA__packages__ENABLED=true`
- `GITEA__packages__CONTAINER__ENABLED=true`

Set `GITEA_REGISTRY_HOST` and `GITEA_REGISTRY_EXTERNAL_URL` in `.env` to the
host/domain clients will use for pushes and pulls.

Example image path:

```text
<registry-host>/<owner>/<image>:<tag>
```

## Notes

- The copied `.env` is a template; adjust values on NAS as needed.
- No credentials or secret values are committed in this directory.
- Future bridge-mode services on `nas-host` should be planned around a reserved
  Docker address pool on the NAS. Long term, the cleaner fix for Synology
  firewall interaction is to constrain Docker bridge networks to one known
  internal range and allow that range explicitly in DSM firewall policy,
  instead of relying on ad-hoc per-network firewall inserts from
  `ensure-docker-bridge-lan-egress.sh`.
- Shared MySQL stack: `mysql/README.md`
- Outline stack: `outline/README.md`
- ArchiveBox stack: `archivebox/README.md`
- Docker socket proxy stack: `docker-socket-proxy/README.md`
- Shared PostgreSQL stack: `postgres/README.md`
- Shared Redis stack: `redis/README.md`
- Shared MongoDB stack: `mongo/README.md`
- Shared Dolt stack: `dolt/README.md`
- Shared Apache Tika stack: `tika/README.md`
- Shared Gotenberg stack: `gotenberg/README.md`
- Paperless-ngx stack: `paperless/README.md`
- Jellyfin stack: `jellyfin/README.md`
- qBittorrent stack: `qbittorrent/README.md`
- KaraKeep stack: `karakeep/README.md`
- Woodpecker agent stack: `woodpecker-agent/README.md`
- Shared infra backup runbook: `SHARED_INFRA_BACKUP_RUNBOOK.md`
- Session continuity notes: `SESSION_NOTES.md`
- Post-deploy operations checklist: `GITEA_OPERATIONS_CHECKLIST.md`
- Promtail settings live at `promtail/.env` on the NAS. Set `LOKI_PUSH_URL` to
  your Loki endpoint (for example `http://loki.<domain>:3100/loki/api/v1/push`).
