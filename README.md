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

- This directory intentionally contains no credentials, private keys, or
  host-private secrets.
- Public CA certificates may be committed when a stack needs them at runtime.
- Host-specific values are either parameterized in `.env.example` files or documented as manual DSM UI steps.

## Layout

- `nas-host/`
  - shared infra stacks:
    - `mysql/`
    - `postgres/`
    - `redis/`
    - `mongo/`
    - `dolt/`
    - `tika/`
    - `gotenberg/`
  - application stacks:
    - `gitea/`
    - `outline/`
    - `paperless/`
    - `karakeep/`
    - `jellyfin/`
    - `qbittorrent/`
    - `archivebox/`
  - observability / integration stacks:
    - `promtail/`
    - `docker-socket-proxy/`
    - `woodpecker-agent/`
  - host runbooks and scripts:
    - `README.md`
    - `SESSION_NOTES.md`
    - `GITEA_OPERATIONS_CHECKLIST.md`
    - `DOCKER_ADDRESS_POOL_RUNBOOK.md`
    - `SHARED_INFRA_BACKUP_RUNBOOK.md`
    - `backup-shared-infra.sh`
    - `gitea-deploy.sh`
    - `promtail-deploy.sh`

## Documentation Index

- Top-level repo overview, scope, and layout:
  - `README.md`
- Active `nas-host` host overview and deploy entrypoint:
  - `nas-host/README.md`
- Active `nas-host` local documentation index:
  - `nas-host/DOCUMENTATION_INDEX.md`
- Template host bootstrap and manual-step guidance:
  - `nas-host-template/README.md`

## Reproducibility Contract

- Container definitions, pinned image tags, ports, and restart policies must be git-tracked here.
- Any unavoidable Synology DSM UI action must be documented in `DSM_MANUAL_CHECKLIST.md`.
- Secret material must stay outside this repository.

## Current Private Model

As of 2026-03-21, this repo does not currently require a sibling private
companion repository.

Current private-state contract:

- sanitized `.env.example` files are tracked
- optional encrypted `.env.sops` files are tracked for stacks that need a
  versioned secret source of truth
- deploy scripts preserve the remote NAS-side `.env` unless `--update-env` is
  explicitly requested

Audit record:

- `PRIVATE_STATE_AUDIT_2026-03-21.md`

## Session Continuity

Host-specific operational notes for continuity across sessions:

- `nas-host/SESSION_NOTES.md`
