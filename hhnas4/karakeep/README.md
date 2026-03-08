# KaraKeep (nas-host)

KaraKeep stack on nas-host with dedicated storage paths.

## Storage layout

- App data: `/volume1/docker/homelab/nas-host/karakeep/data`
- Meilisearch index: `/volume1/docker/homelab/nas-host/karakeep/meilisearch`

These are dedicated KaraKeep paths and are not shared with Prometheus data.

## First-time setup

1. Create/edit `.env` (or encrypted `.env.sops`) with:

- `NEXTAUTH_SECRET`
- `MEILI_MASTER_KEY`
- `NEXTAUTH_URL=https://karakeep.internal.example`

1. Ensure your reverse-proxy rule for `karakeep.internal.example` points to
   `127.0.0.1:3095` on `nas-host`.

## Deploy

```bash
./deploy.sh nas-host --update-env
```
