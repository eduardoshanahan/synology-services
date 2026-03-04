# Synology Host (Template)

Reproducible Synology monitoring artifacts for one Synology host.

## Deploy

From this repository:

```bash
cd nas-host-template
./deploy.sh nas-a.internal.example
```

Optional target directory override:

```bash
./deploy.sh nas-a.internal.example /volume1/docker/homelab/nas-a
```

## What is automated

- `node-exporter` compose deployment with pinned image tag.
- Compose pull + up sequence on target NAS.

## What remains manual

- DSM Log Center forwarding setup for file/security activity logs.
- See `DSM_MANUAL_CHECKLIST.md`.
