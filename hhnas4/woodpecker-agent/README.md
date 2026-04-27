# Woodpecker Agent (`hhnas4`)

AMD64 Woodpecker agent for `hhnas4`.

## Purpose

- Runs trusted `amd64` CI workloads against the NAS Docker daemon.
- Connects back to `woodpecker.internal.example:9000`.

## First-time setup

Edit `.env` locally, or update the mirrored file in `../synology-services-private/`, with:

- `WOODPECKER_AGENT_SECRET`
- `WOODPECKER_CA_CERT_HOST_PATH` pointing at the deployed `homelab-root-ca.crt`
- `WOODPECKER_CA_BUNDLE_HOST_PATH` pointing at the combined CA bundle mounted
  as `/etc/ssl/cert.pem`
- Optional image override if you want to pin away from `latest`
- Optional `WOODPECKER_BACKEND_DOCKER_NETWORK`, but leave it blank unless you
  confirm a specific target network is required
- Leave `WOODPECKER_BACKEND_DOCKER_DNS` blank in the normal path. Build
  containers should inherit the Docker daemon DNS policy configured on
  `hhnas4`, not carry a permanent Woodpecker-only resolver override.

## Deploy

```bash
./deploy.sh hhnas4
```

## Validation

- `docker compose ps` shows the agent running.
- Agent logs show a successful connection to the server.
- A representative build that resolves `*.hhlab.home.arpa` works with
  `WOODPECKER_BACKEND_DOCKER_DNS` unset.
- Private repos should prefer the SSH deploy-key pattern documented in
  `nix-services/services/woodpecker/README.md` instead of HTTPS clone auth.
- Start with trusted private repositories only.
