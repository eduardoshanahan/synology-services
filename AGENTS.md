# AGENTS.md

Guidance for agents working in `synology-services/`.

## Purpose

This directory contains sanitized, reproducible deployment artifacts for
Synology hosts. It is intentionally a plain shell-and-Compose repository.

What belongs here:

- Git-tracked `compose.yaml` files, deploy scripts, runbooks, and templates.
- Sanitized `.env.example` files.
- Public CA certificates required by containers at runtime.

What does not belong here:

- Plaintext credentials, API tokens, private keys, or host-private secrets.
- Undocumented manual DSM changes.
- Generated local caches or machine-specific editor state.

Start with [README.md](./README.md), then
[nas-host/README.md](./nas-host/README.md), then
[nas-host/docs/DOCUMENTATION_INDEX.md](./nas-host/docs/DOCUMENTATION_INDEX.md).

## Active Host

`nas-host/` is the active host directory and the main operational focus in this
repo.

High-level layout under `nas-host/`:

- Shared infra: `mysql/`, `postgres/`, `redis/`, `mongo/`, `dolt/`, `tika/`,
  `gotenberg/`
- Apps: `gitea/`, `outline/`, `paperless/`, `karakeep/`, `jellyfin/`,
  `qbittorrent/`, `archivebox/`, `freshrss/`
- Observability and integration: `promtail/`, `docker-socket-proxy/`,
  `woodpecker-agent/`
- Host-level runbooks in `nas-host/docs/` and wrappers in the root of `nas-host/`

`nas-host-template/` is a template/reference area, not the main live stack.

## Public Vs Private References

Public repos in this workspace may intentionally use anonymized placeholders
such as `*.internal.example` for Git remotes, service URLs, hostnames, and
other environment-specific identifiers.

Treat those values as sanitized public-side references, not as the canonical
live endpoints. The real Synology hostnames, URLs, and private wiring live in
the matching private sibling repo.

## Standard Stack Contract

Most service directories follow this shape:

- `README.md`
- `compose.yaml`
- `deploy.sh`
- `.env.example`
- optional sibling private `.env.sops`

Before changing implementation, read the stack README first. The READMEs are
not fluff here; they usually document the intended runtime shape, DNS names,
port exposure model, storage decisions, and validation commands.

## Deployment Conventions

Most `nas-host/*/deploy.sh` scripts follow the same pattern:

- `set -euo pipefail`
- accept `[target-host] [target-dir] [--update-env]`
- create the remote stack directory over SSH
- stream-copy `compose.yaml` to the NAS using `cat ... | ssh ... "cat > ..."`
- preserve an existing remote `.env` unless `--update-env` is explicitly used
- prefer `../synology-services-private/.../.env.sops`, then local transitional
  `.env.sops`, then local `.env`, then `.env.example`
- auto-detect the Docker binary on Synology
- auto-select direct Docker access vs `sudo -n` vs `sudo`
- run `docker compose pull` and `docker compose up -d`

When editing or adding a new stack, preserve that operator experience unless
there is a strong reason to diverge.

## Important Exceptions

Not every stack is identical. Pay attention to these exceptions:

- `nas-host/gitea-deploy.sh`
  - host-level wrapper, not a per-service deploy script
  - preserves remote `.env`
  - supports admin bootstrap flags
  - syncs Authentik OIDC config declaratively from remote `.env`
  - syncs committed CA certs needed for outbound TLS trust
- `nas-host/promtail-deploy.sh`
  - host-level wrapper for the `promtail/` stack
- `nas-host/archivebox/deploy.sh`
  - seeds the Docker volume before startup for Chrome profile and optional
    cookies file
- `nas-host/postgres/deploy.sh` and `nas-host/dolt/deploy.sh`
  - ensure the external shared Docker network exists before deploy
- `nas-host/jellyfin/deploy.sh`
  - validates `JELLYFIN_MEDIA_DIR` on the target host before deploy
- `nas-host-template/deploy.sh`
  - older template script that still uses `scp`; do not assume it matches the
    newer `nas-host` conventions exactly

## Compose Conventions

Compose files in this repo are intentionally simple and explicit:

- pinned image tags are preferred; some images are pinned by digest
- explicit `container_name` is common
- `restart: unless-stopped` is the default pattern
- service config usually comes from `.env`
- ports are published directly rather than hidden behind extra tooling
- stateful services often use named volumes on Synology instead of bind mounts

Do not casually replace named volumes with bind mounts. Multiple READMEs note
that Synology ACL behavior can make bind mounts look non-writable to non-root
container users.

## Secrets And Env Files

Rules:

- Never commit plaintext secrets.
- Prefer the sibling private repo's `.env.sops` as the tracked secret source.
- Use `.env.example` for sanitized defaults and documentation.
- Plaintext `.env` files are not blanket-ignored; treat any such file as a
  visible local exception that should be moved out, encrypted, or deleted.
- Respect the deploy-script behavior that keeps existing remote `.env` files
  unless `--update-env` is requested.
- Private continuity notes, real hostnames, real internal IPs, and
  operator-specific Synology workflow belong in
  `../synology-services-private`, not in public docs or notes here.

If a stack already supports `sops`, preserve that workflow. The repo dev shell
in `flake.nix` includes `sops`.

## Synology-Specific Constraints

This repo has real Synology operational constraints. Do not ignore them.

### Docker bridge egress and firewall behavior

Some containers on Synology can lose LAN/DNS access because DSM firewall chains
drop Docker bridge traffic before normal Docker forwarding rules apply.

Read these before making networking changes:

- `nas-host/docs/DOCKER_ADDRESS_POOL_RUNBOOK.md`
- `nas-host/docs/GITEA_NAS_PLACEMENT_AND_BRIDGE_EGRESS_FIX_2026-03-05.md`
- `nas-host/ensure-docker-bridge-lan-egress.sh`

If a service has symptoms like DNS failures or inability to reach LAN-hosted
dependencies, check bridge-egress policy before assuming the app config is
wrong.

### Reverse proxy model

Several apps are intentionally loopback-only on the NAS and are expected to sit
behind the Synology DSM reverse proxy. Common pattern:

- app binds to `127.0.0.1:<port>` on the NAS
- DSM terminates TLS and proxies to loopback

Do not widen bindings to `0.0.0.0` unless the service actually needs direct LAN
clients, as with Jellyfin discovery or BitTorrent traffic.

### Docker binary path and privileges

On Synology, Docker may live at:

- `docker`
- `/usr/local/bin/docker`
- `/var/packages/ContainerManager/target/usr/bin/docker`
- `/var/packages/Docker/target/usr/bin/docker`

Existing scripts already handle this. Preserve that logic when possible.

## Validation Expectations

A useful change in this directory usually includes an obvious validation path.
Prefer to preserve or improve the stack README's validation section.

Typical validations in this repo:

- `docker compose ps`
- short `curl` probes against loopback or reverse-proxied endpoints
- log checks with `docker compose logs --tail ...`
- connectivity checks to shared infra services

If you add a new stack or materially change an existing one, update the
relevant README validation guidance too.

## Documentation Expectations

This directory relies heavily on local documentation. Keep it in sync.

When behavior changes, update the nearest relevant docs:

- top-level or host README when entrypoints or host scope change
- stack README when runtime model, ports, storage, dependencies, or validation
  change
- host runbooks when operational procedures change
- `nas-host/docs/SESSION_NOTES.md` for host-level continuity when the change affects ongoing
  operations
- if those continuity notes need real hostnames, real internal IPs, or
  operator-specific workflow, write them in `../synology-services-private`
  instead and keep only the sanitized version here

If a DSM UI step is unavoidable, document it explicitly instead of leaving it as
tribal knowledge.

## Backup And Operations

Shared stateful infrastructure backups are documented and scripted already:

- `nas-host/backup-shared-infra.sh`
- `nas-host/docs/SHARED_INFRA_BACKUP_RUNBOOK.md`

Do not invent a parallel backup workflow for Postgres/MySQL/Redis without a
clear reason.

## Safe Working Style

When working here:

- read Markdown first, then implementation
- if you are going to commit or push, enter `nix develop` first so the repo's
  pre-hook tools are available (`prek`, `gitleaks`, `markdownlint-cli2`,
  `shellcheck`, `shfmt`, `sops`)
- do not use `--no-verify` to work around missing local tools; if commit or
  hook tooling fails, enter `nix develop` and rerun the normal workflow
- at the start of a session, use that dev shell to run `git fetch origin`, then
  `git pull --rebase origin main`, and inspect `git status --short --branch`
  before editing
- prefer `rg` for discovery
- ignore binary cert contents unless you specifically need to confirm mount/use
- avoid destructive Docker or git cleanup unless explicitly requested
- preserve remote state handling and operator-friendly deploy messages
- when the task is finished, commit and push the resulting changes to `origin`
  unless the user explicitly wants them kept local
- if the task changes service behavior, complete the owning Synology deploy
  after push and verify on the live host that the fix still works after that
  deploy
- keep changes small and aligned with the existing shell style

When unsure, follow the existing stack pattern rather than introducing a new
one.
