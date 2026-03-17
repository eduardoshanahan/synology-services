# Gitea

Gitea provides source hosting and the container registry for the homelab NAS.

## Runtime model

- Host owner: `nas-host`
- Deployment model: Synology Docker Compose stack deployed via
  `synology-services/nas-host/gitea/deploy.sh` or the wrapper
  `synology-services/nas-host/gitea-deploy.sh`
- Runtime state lives on NAS storage under the configured `GITEA_DATA_DIR`

## Important files

- Compose definition: `compose.yaml`
- Deploy wrapper in this directory: `deploy.sh`
- Host-level deploy entrypoint: `../gitea-deploy.sh`
- Public CA certificate committed for container trust:
  `certs/homelab-root-ca.crt`

## Configuration

- Main runtime settings are passed through the stack `.env` file on the NAS
- The tracked `.env.example` documents:
  - HTTP and SSH bind settings
  - SQLite defaults
  - registry external URL settings
  - optional Authentik OIDC integration
  - SMTP settings for the relay on `private-pi-02`

## Validation

```bash
docker ps --filter name=gitea --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}\t{{.Ports}}'
curl -skI https://gitea.<domain>/
```

If the registry is enabled, also validate login and a lightweight pull from a
known image path.

## Related docs

- Host overview: `../README.md`
- Operations checklist: `../GITEA_OPERATIONS_CHECKLIST.md`
- NAS placement / bridge notes:
  `../GITEA_NAS_PLACEMENT_AND_BRIDGE_EGRESS_FIX_2026-03-05.md`
