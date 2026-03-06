# hhnas4 Synology Services

Reproducible, sanitized deployment artifacts for host `hhnas4`.

## Included stack

- `ghost-mysql` for a dedicated Ghost production database.
- `gitea` with built-in container registry enabled.
- `outline` for an internal wiki / knowledge base.
- `archivebox` for large local web archive storage.
- `postgres` as shared database server for internal services.
- `redis` as shared cache/queue backend for internal services.
- `promtail` shipping `gitea` container logs to Loki.

## Deploy

From this repository:

```bash
cd hhnas4
./gitea-deploy.sh hhnas4.internal.example
```

Optional target directory override:

```bash
./gitea-deploy.sh hhnas4.internal.example /volume1/docker/homelab/hhnas4
```

## Non-UI bootstrap (recommended)

Gitea is configured with SQLite and `INSTALL_LOCK=true` by default, so you can
bootstrap without opening the install wizard.

Create (or ensure) an admin user at deploy time:

```bash
./gitea-deploy.sh hhnas4.internal.example \
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
./promtail-deploy.sh hhnas4.internal.example
```

Optional target directory override:

```bash
./promtail-deploy.sh hhnas4.internal.example /volume1/docker/homelab/hhnas4
```

## Shared Infra Backups

Centralized backup orchestration for shared Postgres/MySQL/Redis state:

```bash
./backup-shared-infra.sh hhnas4
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
- Ghost database stack: `ghost-mysql/README.md`
- Outline stack: `outline/README.md`
- ArchiveBox stack: `archivebox/README.md`
- Shared PostgreSQL stack: `postgres/README.md`
- Shared Redis stack: `redis/README.md`
- Shared infra backup runbook: `SHARED_INFRA_BACKUP_RUNBOOK.md`
- Session continuity notes: `SESSION_NOTES.md`
- Post-deploy operations checklist: `GITEA_OPERATIONS_CHECKLIST.md`
- Promtail settings live at `promtail/.env` on the NAS. Set `LOKI_PUSH_URL` to
  your Loki endpoint (for example `http://loki.<domain>:3100/loki/api/v1/push`).
