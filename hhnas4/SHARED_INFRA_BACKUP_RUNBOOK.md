# Shared Infra Backup Runbook (`nas-host`)

This runbook centralizes backups for shared stateful infrastructure on `nas-host`:

- PostgreSQL (`nas-host/postgres`)
- MySQL (`nas-host/ghost-mysql`)
- Redis (`nas-host/redis`)

It uses one script:

- `nas-host/backup-shared-infra.sh`

## What the script captures

- PostgreSQL full logical dump:
  - `postgres/pg_dumpall.sql.gz`
- MySQL full logical dump:
  - `mysql/all-databases.sql.gz`
- Redis point-in-time RDB export:
  - `redis/redis.rdb`
- Integrity/metadata:
  - `SHA256SUMS`
  - `MANIFEST.txt`

Artifacts are written on NAS under:

```text
/volume1/docker/homelab/nas-host/backups/shared-infra/<timestamp-utc>/
```

## Run on demand

From this repository:

```bash
cd synology-services/nas-host
./backup-shared-infra.sh nas-host
```

Optional overrides:

```bash
./backup-shared-infra.sh nas-host /volume1/docker/homelab/nas-host --retention-days 21
```

## Schedule (recommended)

Use DSM Task Scheduler (root user), for example daily at 02:30:

```bash
/bin/sh /volume1/docker/homelab/nas-host/backup-shared-infra.sh nas-host /volume1/docker/homelab/nas-host --retention-days 21 >> /volume1/docker/homelab/nas-host/backups/shared-infra/backup.log 2>&1
```

## Validation checklist

After each run:

1. Confirm latest directory exists and has expected files:
   - `pg_dumpall.sql.gz`
   - `all-databases.sql.gz`
   - `redis.rdb`
   - `SHA256SUMS`
   - `MANIFEST.txt`
2. Confirm checksums verify:

```bash
cd /volume1/docker/homelab/nas-host/backups/shared-infra/<timestamp-utc>
sha256sum -c SHA256SUMS
```

1. Periodically perform restore drills in an isolated environment.

## Restore note

This runbook intentionally focuses on backup creation and retention.
Do restores only via explicit restore procedures/drills to avoid accidental data loss in live services.
