# KaraKeep (hhnas4)

KaraKeep stack on hhnas4 with dedicated storage paths.

## Storage layout

- App data: `/volume1/docker/homelab/hhnas4/karakeep/data`
- Meilisearch index: `/volume1/docker/homelab/hhnas4/karakeep/meilisearch`

These are dedicated KaraKeep paths and are not shared with Prometheus data.

## First-time setup

1. Create/edit `.env` locally, or update the mirrored file in `../synology-services-private/`, with:

- `NEXTAUTH_SECRET`
- `MEILI_MASTER_KEY`
- `NEXTAUTH_URL=https://karakeep.internal.example`

1. Ensure your reverse-proxy rule for `karakeep.internal.example` points to
   `127.0.0.1:3095` on `hhnas4`.

## Deploy

```bash
./deploy.sh hhnas4 --update-env
```
