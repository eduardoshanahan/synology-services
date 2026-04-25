# scholarsome

[Scholarsome](https://github.com/hwgilbert16/scholarsome) — open-source, web-based spaced repetition flashcard app. Deployed as a self-hosted alternative to mochi.cards.

- Image: `hwgilbert16/scholarsome:v1.2.1`
- Host port: `3020` (loopback only; exposed via DSM reverse proxy)
- Database: shared `nas-host-mysql` on hhnas4 (database `scholarsome`)
- Cache: shared `nas-host-redis` on hhnas4 (ACL user `scholarsome`)
- Storage: Docker named volume `scholarsome_media` (`/app/media` in container)

## One-Time Setup

### 1. MySQL — create database and user

```bash
ssh hhnas4 "docker exec -i nas-host-mysql mysql -uroot -p\$(grep MYSQL_ROOT_PASSWORD /volume1/docker/homelab/hhnas4/mysql/.env | cut -d= -f2) <<'SQL'
CREATE DATABASE IF NOT EXISTS scholarsome CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'scholarsome'@'%' IDENTIFIED BY '<scholarsome-db-password>';
GRANT ALL PRIVILEGES ON scholarsome.* TO 'scholarsome'@'%';
FLUSH PRIVILEGES;
SQL"
```

### 2. Redis — add scholarsome ACL user

The `redis/compose.yaml` has been updated to provision a `scholarsome` Redis user
when `REDIS_SCHOLARSOME_USERNAME` and `REDIS_SCHOLARSOME_PASSWORD` are set.

Redeploy Redis with updated env to activate:

```bash
cd ../redis
./deploy.sh hhnas4 --update-env
```

### 3. DSM Reverse Proxy

Control Panel → Login Portal → Advanced → Reverse Proxy → Create:

- **Source**: Protocol HTTPS, Hostname `scholarsome.<your-domain>`, Port 443
- **Destination**: Protocol HTTP, Hostname `localhost`, Port 3020

### 4. Pi-hole DNS

```bash
# From workspace root
scripts/pihole-add-fqdn scholarsome.<your-domain> <hhnas4-ip>
```

## Deploy

First deploy (creates remote .env from sops):

```bash
./deploy.sh hhnas4 --update-env
```

Subsequent deploys (preserves existing remote .env):

```bash
./deploy.sh hhnas4
```

## Validation

```bash
ssh hhnas4 "docker ps --filter name=nas-host-scholarsome"
ssh hhnas4 "docker compose -f /volume1/docker/homelab/hhnas4/scholarsome/compose.yaml ps"
ssh hhnas4 "curl -sSI http://127.0.0.1:3020/ | head -5"
ssh hhnas4 "docker compose -f /volume1/docker/homelab/hhnas4/scholarsome/compose.yaml logs --tail 60"
```

Expected: HTTP 200 on the loopback probe; Scholarsome web UI accessible at `https://scholarsome.<your-domain>`.

## Upgrade

Pin a new version in `compose.yaml` (`image: hwgilbert16/scholarsome:<new-version>`), then:

```bash
./deploy.sh hhnas4
```

## Notes

- SMTP is optional; configure it in `.env.sops` if you need password-reset emails.
- `STORAGE_TYPE=local` stores media files in the `scholarsome_media` Docker volume.
  To switch to MinIO S3 later, set `STORAGE_TYPE=s3` and the `S3_STORAGE_*` vars.
- Scholarsome runs its own DB migrations on startup via Prisma.
