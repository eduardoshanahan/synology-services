# synology-services

Sanitized, reproducible deployment artifacts for Synology hosts.

This repository is intended to live as a sibling of `nix-services` and
`nix-pi` in the shared workspace.

It is intentionally a plain shell-and-Compose repository.

- No `direnv` dependency.
- No generated `.direnv` cache tracked in Git.
- Optional local tooling shell via `nix develop`.

If you want the repo-provided toolchain (`prek`, `gitleaks`, `markdownlint-cli2`,
`shellcheck`, `shfmt`) without installing those tools into your user profile,
run:

```bash
nix develop --no-write-lock-file
```

## Scope

- This directory intentionally contains no credentials, certificates, or host-private secrets.
- Host-specific values are either parameterized in `.env.example` files or documented as manual DSM UI steps.

## Layout

- `nas-host-template/node-exporter/compose.yaml`
- `nas-host-template/node-exporter/.env.example`
- `nas-host-template/deploy.sh`
- `nas-host-template/DSM_MANUAL_CHECKLIST.md`
- `nas-host/gitea/compose.yaml`
- `nas-host/ghost-mysql/compose.yaml`
- `nas-host/ghost-mysql/.env.example`
- `nas-host/ghost-mysql/deploy.sh`
- `nas-host/ghost-mysql/README.md`
- `nas-host/gitea/.env.example`
- `nas-host/promtail/compose.yaml`
- `nas-host/promtail/config.yml`
- `nas-host/promtail/.env.example`
- `nas-host/gitea-deploy.sh`
- `nas-host/promtail-deploy.sh`
- `nas-host/README.md`

## Reproducibility Contract

- Container definitions, pinned image tags, ports, and restart policies must be git-tracked here.
- Any unavoidable Synology DSM UI action must be documented in `DSM_MANUAL_CHECKLIST.md`.
- Secret material must stay outside this repository.

## Session Notes

Host-specific operational notes for continuity across sessions:

- `nas-host/SESSION_NOTES.md`
