# Adminer (hhnas4)

Shared PHP Adminer UI for the homelab databases that live on `hhnas4`.

## Purpose

- Avoid installing host-specific database management tools by offering a single
  internal web UI that can reach every shared SQL/MariaDB/Postgres endpoint.
- Keep the UI on the same Synology host that already owns the DB containers so
  the Pis and other hosts can all reach it without adding extra services elsewhere.

## Access and DNS

- Deploy path: `/volume1/docker/homelab/hhnas4/adminer`
- Compose file: `synology-services/hhnas4/adminer/compose.yaml`
- Internal DNS: `adminer.internal.example` (public placeholder). Operators
  configure the real LAN name/IP in the private repo so the live deploy hooks
  into the Synology LAN address. Adminer listens on **port 8080** inside the
  container, but the NAS publishes it on port **8070** so DSM can proxy HTTPS
  traffic from `adminer.internal.example -> 127.0.0.1:8070`. Keep the service on
  the shared database bridge and avoid additional published ports.

## Supported databases

Adminer can connect to any server it supports, but the defaults in this stack
make the following already-available hosts reachable without extra networking:

| Database | Port |
| --- | --- |
| MySQL / MariaDB (shared stack) | `3306` |
| PostgreSQL (shared stack) | `5433` |
| Dolt (shared stack) | `3307` |

Because Adminer lives on the shared database network with the other
shared stacks, it can resolve these hostnames directly and reuse their existing
credentials without exposing any new ports on the Pis.

## Configuration

Customize the web UI binding, port, and design in the `.env` on the NAS:

```dotenv
ADMINER_BIND=0.0.0.0
ADMINER_PORT=8070
ADMINER_DESIGN=nette
SHARED_DB_NETWORK=shared-db
```

Set strong credentials for the databases you manage directly on the target
stack; no secrets are stored in this repository.

## Deployment

```bash
cd synology-services/hhnas4/adminer
./deploy.sh hhnas4
```

The deploy script mirrors the other stacks: it copies `compose.yaml`, keeps
  the existing `.env` unless `--update-env` is provided, and ensures the shared
  database network exists before bringing up Adminer.

- The script looks for a private `.env.sops` in `../synology-services-private/
  hhnas4/adminer/.env.sops` if you add one later. Keep secrets inside that
  companion repo.

## Validation

After deploy:

```bash
ssh hhnas4 "cd /volume1/docker/homelab/hhnas4/adminer && docker compose ps"
curl -sk http://adminer.internal.example:8070/ || true
```

Ensure the container reports `healthy` and the DSM firewall allows the chosen
`ADMINER_PORT`. If you expose the UI through a reverse proxy, confirm the proxy
logs no TLS errors.

## Notes

- Adminer runs on the same bridge as the shared databases, so keep the
  `SHARED_DB_NETWORK` value aligned with the other stacks; the private repo can
  override it to the bridge name you actually use.
- Because the purpose is internal tooling, do not open the port to the public
  internet; keep the DNS entry restricted to the homelab domain and the NAS LAN
  firewall.
