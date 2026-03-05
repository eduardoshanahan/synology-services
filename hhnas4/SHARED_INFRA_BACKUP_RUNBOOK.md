# Shared Infra Backup Runbook (`hhnas4`)

This runbook centralizes backups for shared stateful infrastructure on `hhnas4`:

- PostgreSQL (`hhnas4/postgres`)
- MySQL (`hhnas4/ghost-mysql`)
- Redis (`hhnas4/redis`)

It uses one script:

- `hhnas4/backup-shared-infra.sh`

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
/volume1/docker/homelab/hhnas4/backups/shared-infra/<timestamp-utc>/
```

## Run on demand

From this repository:

```bash
cd synology-services/hhnas4
./backup-shared-infra.sh hhnas4
```

Optional overrides:

```bash
./backup-shared-infra.sh hhnas4 /volume1/docker/homelab/hhnas4 --retention-days 21
```

## Schedule (recommended)

Use DSM Task Scheduler (root user), for example daily at 02:30:

```bash
/bin/bash /volume1/docker/homelab/hhnas4/backup-shared-infra.sh hhnas4 /volume1/docker/homelab/hhnas4 --retention-days 21 >> /volume1/docker/homelab/hhnas4/backups/shared-infra/backup.log 2>&1
```

## Validation checklist

After each run:

1. Confirm latest directory exists and has expected files:
   - `pg_dumpall.sql.gz`
   - `all-databases.sql.gz`
   - `redis.rdb`
   - `SHA256SUMS`
   - `MANIFEST.txt`
1. Confirm checksums verify:

```bash
cd /volume1/docker/homelab/hhnas4/backups/shared-infra/<timestamp-utc>
sha256sum -c SHA256SUMS
```

1. Periodically perform restore drills in an isolated environment.

## Restore note

This runbook intentionally focuses on backup creation and retention.
Do restores only via explicit restore procedures/drills to avoid accidental data loss in live services.
