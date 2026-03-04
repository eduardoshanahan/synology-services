# Ghost MySQL (nas-host)

Dedicated MySQL 8 stack for Ghost production use on `nas-host`.

## Purpose

- Runs a dedicated MySQL 8 server for Ghost.
- Keeps database state in a Docker-managed named volume on this Synology host.
- Can be validated independently before Ghost is deployed on `private-pi-02`.

## Layout

- `compose.yaml`
- `.env.example`
- `deploy.sh`

## Runtime storage on NAS

Default target directory:

```text
/volume1/docker/homelab/nas-host/ghost-mysql
```

Persistent database volume:

```text
ghost_mysql_data
```

## Deploy

From this repository:

```bash
cd nas-host/ghost-mysql
./deploy.sh nas-host.internal.example
```

Optional target directory override:

```bash
./deploy.sh nas-host.internal.example /volume1/docker/homelab/nas-host/ghost-mysql
```

## First-start rules

- Edit `.env` on the NAS before first production start.
- Replace `MYSQL_ROOT_PASSWORD` and `MYSQL_PASSWORD` with strong values.
- Keep `MYSQL_DATABASE` and `MYSQL_USER` aligned with the future Ghost config.
- Avoid exposing port `3306` beyond the LAN.
- This stack uses a named volume intentionally. The original bind-mount
  approach failed on `nas-host` because Synology ACLs blocked MySQL's internal
  non-root writes during initialization.

## Validation goals before Ghost

- Container reports `healthy`.
- Port `3306` is reachable from `private-pi-02`.
- `ghost` user can connect to the `ghost` database.
- Test write/read survives a container restart.

## Backup note

Use logical dumps (`mysqldump`) as the primary backup method. If you also want
volume-level backups, export the Docker volume explicitly on the NAS.
