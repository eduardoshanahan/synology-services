# Woodpecker Agent (nas-host)

AMD64 Woodpecker agent for `nas-host`.

## Purpose

- Runs trusted `amd64` CI workloads against the NAS Docker daemon.
- Connects back to `woodpecker.internal.example:9000`.

## First-time setup

Edit `.env` (or encrypted `.env.sops`) with:

- `WOODPECKER_AGENT_SECRET`
- `WOODPECKER_CA_CERT_HOST_PATH` pointing at the deployed `homelab-root-ca.crt`
- `WOODPECKER_CA_BUNDLE_HOST_PATH` pointing at the combined CA bundle mounted
  as `/etc/ssl/cert.pem`
- Optional image override if you want to pin away from `latest`
- Optional `WOODPECKER_BACKEND_DOCKER_NETWORK`, but leave it blank unless you
  confirm a specific target network is required

## Deploy

```bash
./deploy.sh nas-host
```

## Validation

- `docker compose ps` shows the agent running.
- Agent logs show a successful connection to the server.
- Private repos should prefer the SSH deploy-key pattern documented in
  `nix-services/services/woodpecker/README.md` instead of HTTPS clone auth.
- Start with trusted private repositories only.
