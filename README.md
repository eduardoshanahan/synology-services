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

- `hhnas4/`
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

## Documentation Map

- Top-level repo scope and layout:
  - this file
- Active `hhnas4` stack and runbook index:
  - `hhnas4/README.md`
- Active `hhnas4` local documentation index:
  - `hhnas4/DOCUMENTATION_INDEX.md`
- Template host bootstrap/manual-step guidance:
  - `nas-host-template/README.md`

## Reproducibility Contract

- Container definitions, pinned image tags, ports, and restart policies must be git-tracked here.
- Any unavoidable Synology DSM UI action must be documented in `DSM_MANUAL_CHECKLIST.md`.
- Secret material must stay outside this repository.

## Session Notes

Host-specific operational notes for continuity across sessions:

- `hhnas4/SESSION_NOTES.md`
