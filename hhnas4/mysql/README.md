# MySQL (nas-host)

Shared MySQL 8 stack for internal services on `nas-host`.

## Purpose

- Runs one reusable MySQL 8 server for internal services.
- Keeps database state in a Docker-managed named volume on this Synology host.
- Supports multiple service databases/users (for example Ghost plus additional apps).

## Layout

- `compose.yaml`
- `.env.example`
- `deploy.sh`

## Runtime storage on NAS

Default target directory:

```text
/volume1/docker/homelab/nas-host/mysql
```

Persistent database volume:

```text
ghost-mysql_ghost_mysql_data
```

## Deploy

From this repository:

```bash
cd nas-host/mysql
./deploy.sh nas-host.internal.example
```

Optional target directory override:

```bash
./deploy.sh nas-host.internal.example /volume1/docker/homelab/nas-host/mysql
```

## First-start rules

- Edit `.env` on the NAS before first production start.
- Replace `MYSQL_ROOT_PASSWORD` and `MYSQL_PASSWORD` with strong values.
- Keep `MYSQL_DATABASE` and `MYSQL_USER` aligned with the service you are provisioning.
- Avoid exposing port `3306` beyond the LAN.
- This stack uses a named volume intentionally. The original bind-mount
  approach failed on `nas-host` because Synology ACLs blocked MySQL's internal
  non-root writes during initialization.

## Validation goals

- Container reports `healthy`.
- Port `3306` is reachable from `private-pi-02`.
- App users can connect to their assigned databases.
- Test write/read survives a container restart.

## Compatibility note

- The Compose volume key is `mysql_data`, but it is explicitly mapped to the
  legacy Docker volume name `ghost-mysql_ghost_mysql_data` to preserve
  pre-rename data.

## Backup note

Use logical dumps (`mysqldump`) as the primary backup method. If you also want
volume-level backups, export the Docker volume explicitly on the NAS.
