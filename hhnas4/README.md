# nas-host Synology Services

Reproducible, sanitized deployment artifacts for host `nas-host`.

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

## Promtail

Deploy log shipping separately:

```bash
./promtail-deploy.sh nas-host.internal.example
```

Optional target directory override:

```bash
./promtail-deploy.sh nas-host.internal.example /volume1/docker/homelab/nas-host
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
