# Promtail

Promtail ships Synology container logs from `nas-host` to Loki.

## Runtime model

- Host owner: `nas-host`
- Deployment model: Synology Docker Compose stack deployed via
  `synology-services/nas-host/promtail/deploy.sh` or the wrapper
  `synology-services/nas-host/promtail-deploy.sh`
- Current scrape config targets the `gitea` and `jellyfin` containers through
  the Docker socket

## Important files

- Compose definition: `compose.yaml`
- Promtail config: `config.yml`
- Deploy wrapper in this directory: `deploy.sh`
- Host-level deploy entrypoint: `../promtail-deploy.sh`

## Configuration

- Set `LOKI_PUSH_URL` in the NAS-side `.env`
- Set `PROMTAIL_HOST_LABEL` to the hostname label you want attached to log
  streams
- Keep `PROMTAIL_BIND=127.0.0.1` unless you intentionally need off-box access
  to the readiness/metrics endpoint
- The stack bind-mounts:
  - `./config.yml` to `/etc/promtail/config.yml`
  - `./data` for positions state
  - `/var/run/docker.sock` read-only for Docker service discovery

## Validation

```bash
docker ps --filter name=promtail --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}\t{{.Ports}}'
curl -fsS http://127.0.0.1:9080/ready
```

Then confirm fresh log ingestion in Loki for the `synology-gitea` and
`synology-jellyfin` jobs.

## Related docs

- Host overview: `../README.md`
