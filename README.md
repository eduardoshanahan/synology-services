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
    - `minio/`
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
    - `freshrss/`
    - `immich/`
    - `jellyfin/`
    - `qbittorrent/`
    - `archivebox/`
  - observability / integration stacks:
    - `promtail/`
    - `docker-socket-proxy/`
    - `woodpecker-agent/`
  - host docs, runbooks, and scripts:
    - `README.md`
    - `docs/`
      - `DOCUMENTATION_INDEX.md`
      - `SESSION_NOTES.md`
      - `GITEA_OPERATIONS_CHECKLIST.md`
      - `DOCKER_ADDRESS_POOL_RUNBOOK.md`
      - `SHARED_INFRA_BACKUP_RUNBOOK.md`
    - `backup-shared-infra.sh`
    - `gitea-deploy.sh`
    - `promtail-deploy.sh`
- `docs/`
  - repo-level background and transition notes

## Documentation Index

- Top-level repo overview, scope, and layout:
  - `README.md`
- Active `nas-host` host overview and deploy entrypoint:
  - `nas-host/README.md`
- Active `nas-host` local documentation index:
  - `nas-host/docs/DOCUMENTATION_INDEX.md`
- Repo-level background and transition docs:
  - `docs/`
- Template host bootstrap and manual-step guidance:
  - `nas-host-template/README.md`

## Reproducibility Contract

- Container definitions, pinned image tags, ports, and restart policies must be git-tracked here.
- Any unavoidable Synology DSM UI action must be documented in the relevant
  host `docs/DSM_MANUAL_CHECKLIST.md`.
- Secret material must stay outside this repository.

## Current Private Model

As of 2026-03-22, this repo uses a sibling private companion repository:

Current private-state contract:

- sanitized `.env.example` files are tracked
- tracked encrypted env sources live in `../synology-services-private/`
- deploy scripts prefer the sibling private `.env.sops`, then fall back to a
  local transitional `.env.sops`, then local `.env`, then `.env.example`
- plaintext `.env` files are no longer blanket-ignored; if one exists, it will
  show up in Git status and should be moved out or encrypted
- deploy scripts preserve the remote NAS-side `.env` unless `--update-env` is
  explicitly requested

Current transition records:

- `docs/PRIVATE_STATE_AUDIT_2026-03-21.md`
- `docs/PRIVATE_COMPANION_SPLIT_2026-03-22.md`

## Session Continuity

Host-specific operational notes for continuity across sessions:

- `nas-host/docs/SESSION_NOTES.md`
