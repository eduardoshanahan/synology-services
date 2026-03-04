# hhnas4 Synology Services

Reproducible, sanitized deployment artifacts for host `hhnas4`.

## Included stack

- `ghost-mysql` for a dedicated Ghost production database.
- `gitea` with built-in container registry enabled.
- `archivebox` for large local web archive storage.
- `promtail` shipping `gitea` container logs to Loki.

## Deploy

From this repository:

```bash
cd hhnas4
./deploy.sh hhnas4.internal.example
```

Optional target directory override:

```bash
./deploy.sh hhnas4.internal.example /volume1/docker/homelab/hhnas4
```

## Non-UI bootstrap (recommended)

Gitea is configured with SQLite and `INSTALL_LOCK=true` by default, so you can
bootstrap without opening the install wizard.

Create (or ensure) an admin user at deploy time:

```bash
./deploy.sh hhnas4.internal.example \
  --admin-user gitea-admin \
  --admin-email admin@example.com \
  --admin-password 'change-me-now'
```

If the admin user already exists, the script keeps it and continues.

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
- ArchiveBox stack: `archivebox/README.md`
- Session continuity notes: `SESSION_NOTES.md`
- Post-deploy operations checklist: `GITEA_OPERATIONS_CHECKLIST.md`
- Promtail settings live at `promtail/.env` on the NAS. Set `LOKI_PUSH_URL` to
  your Loki endpoint (for example `http://loki.<domain>:3100/loki/api/v1/push`).
