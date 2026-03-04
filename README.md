# synology-services

Sanitized, reproducible deployment artifacts for Synology hosts.

This repository is intended to live as a sibling of `nix-services` and
`nix-pi` in the shared workspace.

## Scope

- This directory intentionally contains no credentials, certificates, or host-private secrets.
- Host-specific values are either parameterized in `.env.example` files or documented as manual DSM UI steps.

## Layout

- `nas-host-template/node-exporter/compose.yaml`
- `nas-host-template/node-exporter/.env.example`
- `nas-host-template/deploy.sh`
- `nas-host-template/DSM_MANUAL_CHECKLIST.md`
- `hhnas4/gitea/compose.yaml`
- `hhnas4/ghost-mysql/compose.yaml`
- `hhnas4/ghost-mysql/.env.example`
- `hhnas4/ghost-mysql/deploy.sh`
- `hhnas4/ghost-mysql/README.md`
- `hhnas4/gitea/.env.example`
- `hhnas4/promtail/compose.yaml`
- `hhnas4/promtail/config.yml`
- `hhnas4/promtail/.env.example`
- `hhnas4/gitea-deploy.sh`
- `hhnas4/README.md`

## Reproducibility Contract

- Container definitions, pinned image tags, ports, and restart policies must be git-tracked here.
- Any unavoidable Synology DSM UI action must be documented in `DSM_MANUAL_CHECKLIST.md`.
- Secret material must stay outside this repository.

## Session Notes

Host-specific operational notes for continuity across sessions:

- `hhnas4/SESSION_NOTES.md`
