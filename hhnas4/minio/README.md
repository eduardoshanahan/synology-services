# MinIO (nas-host)

Shared S3-compatible object storage service for internal workloads on `nas-host`.

## Purpose

- Provides one reusable S3-compatible endpoint for services on your internal domain.
- Fits workloads that need object storage semantics rather than a plain shared filesystem.
- Keeps the admin console loopback-only by default so it can sit behind the DSM reverse proxy if desired.

## Service endpoint

- S3 API FQDN: `minio.<internal-domain>`
- Admin console FQDN: `minio-console.<internal-domain>`
- Default S3 API port on the NAS: `9000` (loopback-only by default)
- Default admin console port on the NAS: `9001` (loopback-only by default)
- Public API URL is configured with `MINIO_SERVER_URL`
- Public console URL is configured with `MINIO_BROWSER_REDIRECT_URL`
- Prometheus metrics auth mode is configured with `MINIO_PROMETHEUS_AUTH_TYPE`

## DNS prerequisite

Create internal DNS A records before switching clients:

- `minio.<internal-domain> -> <nas-host-lan-reachable-address>`
- `minio-console.<internal-domain> -> <nas-host-lan-reachable-address>`

Quick check from a client:

```bash
getent hosts minio.<internal-domain>
```

## Layout

- `compose.yaml`
- `.env.example`
- sibling private `.env.sops` in `../synology-services-private/` (preferred tracked encrypted source)
- `deploy.sh`

## Runtime storage on NAS

Default target directory:

```text
/volume1/docker/homelab/nas-host/minio
```

Docker-managed persistent volume:

```text
minio_data
```

## Deploy

From this repository:

```bash
cd nas-host/minio
./deploy.sh nas-host.internal.example
```

Optional target directory override:

```bash
./deploy.sh nas-host.internal.example /volume1/docker/homelab/nas-host/minio
```

If you keep a sibling-private `.env.sops` (or a local fallback `.env` / `.env.sops` during transition), push it explicitly:

```bash
./deploy.sh nas-host.internal.example --update-env
```

## First-start rules

- Set a strong `MINIO_ROOT_USER` and `MINIO_ROOT_PASSWORD` before first production start.
- Keep both the S3 API and the admin console loopback-only on the NAS.
- Terminate TLS in the DSM reverse proxy and forward:
  - `https://minio.<internal-domain>` -> `http://127.0.0.1:9000`
  - `https://minio-console.<internal-domain>` -> `http://127.0.0.1:9001`
- Create dedicated access credentials and buckets per consuming app instead of sharing the root credential.
- If you reverse-proxy MinIO, set both public URLs explicitly:
  - `MINIO_SERVER_URL=https://minio.<internal-domain>`
  - `MINIO_BROWSER_REDIRECT_URL=https://minio-console.<internal-domain>`
- For internal Prometheus scraping without bearer-token management, set:
  - `MINIO_PROMETHEUS_AUTH_TYPE=public`
- Cluster metrics can then be scraped from:
  - `https://minio.<internal-domain>/minio/v2/metrics/cluster`

## Validation goals

- `docker compose ps` shows `minio` running.
- From NAS:
  - `curl -sS -m 6 -i http://127.0.0.1:9000/minio/health/live | sed -n '1,8p'`
  returns `HTTP/1.1 200 OK`.
- Through DSM reverse proxy:
  - `curl -skI https://minio.<internal-domain>/minio/health/live`
  - `curl -skI https://minio-console.<internal-domain>/`
- Internal clients should use the HTTPS S3 endpoint at `https://minio.<internal-domain>`.

## Backup note

- Include the `minio_data` volume in NAS backup and restore-drill planning.
- Bucket/object backups are not yet centralized in `backup-shared-infra.sh`.
