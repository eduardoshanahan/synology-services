# `nas-host` Managed Stack Auto-Start Runbook

Use this when a reboot leaves many `nas-host` containers stopped despite
`restart: unless-stopped`.

## Why This Exists

On `2026-04-08`, all managed `nas-host` containers were found stopped after host
uptime was ~24h. Immediate recovery succeeded with `docker compose up -d` per
stack, but this incident showed we need a repeatable host-level start routine.

## Repo Scripts

- Host-side helper: `../start-managed-stacks.sh`
- Deploy wrapper: `../deploy-start-managed-stacks.sh`

The deploy wrapper copies the host-side script into the NAS stack base path and
can run it immediately.

## One-Time Deploy Of Helper

From this repo:

```bash
cd nas-host
./deploy-start-managed-stacks.sh nas-host /volume1/docker/homelab/nas-host --run-now
```

This installs:

- `/volume1/docker/homelab/nas-host/start-managed-stacks.sh`

## Manual Recovery Command

Run directly on the NAS (or over SSH):

```bash
/bin/sh /volume1/docker/homelab/nas-host/start-managed-stacks.sh /volume1/docker/homelab/nas-host
```

The script is idempotent and safe to re-run.

## DSM Boot Task (Persistent Fix)

In DSM Task Scheduler, create a root boot-triggered task with this command:

```bash
/bin/sh /volume1/docker/homelab/nas-host/start-managed-stacks.sh /volume1/docker/homelab/nas-host >> /volume1/docker/homelab/nas-host/start-managed-stacks.log 2>&1
```

Suggested task name: `nas-host-managed-stacks-autostart`.

## Validation

After boot (or manual run), verify:

```bash
sudo /usr/local/bin/docker ps --format "table {{.Names}}\t{{.Status}}"
```

Target outcome:

- shared infra healthy (`postgres`, `redis`, `mysql`, `mongo`, `dolt`)
- apps running (`gitea`, `outline`, `paperless`, `karakeep`, `jellyfin`, etc.)
- optional stacks without `.env` are logged as skipped, not treated as fatal.
- standalone monitoring stack is running:
  - `node-exporter` from `/volume1/docker/homelab/nas-observability/compose.yaml`
