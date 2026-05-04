# Agent Instructions — synology-services (public)

This file extends the global instructions at `~/Programming/brain/.brain/AGENT.md`.

---

## Project Context

- **BRAIN_CONTEXT**: synology
- **BRAIN_REPO**: synology-services
- **Purpose**: Sanitized, reproducible deployment artifacts for Synology hosts.
  Plain shell-and-Compose repository.
- **Private counterpart**: `../synology-services-private/` (not published)

---

## Public Brain Rules

- This `.brain/` directory is pushed to GitHub and Gitea — never add sensitive content here
- This directory only contains content explicitly published via `brainctl publish`
- Raw investigations live in `../synology-services-private/.brain/` — BRAIN_ROOT points there

---

## What Belongs Here

- Git-tracked `compose.yaml` files, deploy scripts, runbooks, and templates
- Sanitized `.env.example` files
- Public CA certificates required by containers at runtime

What does not belong here:

- Plaintext credentials, API tokens, private keys, or host-private secrets
- Undocumented manual DSM changes
- Generated local caches or machine-specific editor state

---

## Active Host

`hhnas4/` is the active host directory and the main operational focus in this repo.

High-level layout under `hhnas4/`:

- Shared infra: `mysql/`, `postgres/`, `redis/`, `mongo/`, `dolt/`, `tika/`, `gotenberg/`
- Apps: `gitea/`, `outline/`, `paperless/`, `karakeep/`, `jellyfin/`, `qbittorrent/`, `archivebox/`, `freshrss/`
- Observability and integration: `promtail/`, `docker-socket-proxy/`, `woodpecker-agent/`
- Host-level runbooks in `hhnas4/docs/` and wrappers in the root of `hhnas4/`

`nas-host-template/` is a template/reference area, not the main live stack.

---

## Start Here

When working in `synology-services`, read in this order:

1. `README.md`
2. `hhnas4/README.md`
3. `hhnas4/docs/DOCUMENTATION_INDEX.md`
4. the specific stack README for the task
5. relevant `compose.yaml`, `deploy.sh`, and `.env.example`
6. `../synology-services-private/hhnas4/<service>/INVESTIGATION.md` if it exists

---

## Public Vs Private References

Public repos in this workspace may intentionally use anonymized placeholders
such as `*.internal.example` for Git remotes, service URLs, hostnames, and
other environment-specific identifiers.

Treat those values as sanitized public-side references, not as the canonical
live endpoints. Real Synology hostnames, URLs, and private wiring live in
`../synology-services-private/`.

Default working rule at session start:

- assume this public repo contains sanitized example defaults only
- keep real hostnames such as `hhnas4`, real deployment paths, real LAN IPs, and other
  operator-private values in `../synology-services-private/`
- do not promote a real value from the private side into this public repo just
  because it appears to be the live value on the NAS
- if a public file shows a concrete-looking path or hostname, treat it as an example
  until the private companion repo and live host confirm it is intentionally real

---

## Sandbox And Homelab DNS

Access to real homelab hostnames under `*.<homelab-domain>` should be treated as
host-network work, not ordinary sandbox-safe repo work.

Prefer running commands that need `hhnas4`, `gitea.<homelab-domain>`, or similar
homelab endpoints outside the sandbox — do not change repo code just because a
sandboxed command reports temporary resolution failure for a healthy homelab hostname.

---

## Standard Stack Contract

Most service directories follow this shape:

- `README.md`
- `compose.yaml`
- `deploy.sh`
- `.env.example`
- optional sibling private `.env.sops`

Before changing implementation, read the stack README first. READMEs document
the intended runtime shape, DNS names, port exposure model, storage decisions, and
validation commands.

---

## Deployment Conventions

Most `hhnas4/*/deploy.sh` scripts follow the same pattern:

- `set -euo pipefail`
- accept `[target-host] [target-dir] [--update-env]`
- create the remote stack directory over SSH
- stream-copy `compose.yaml` to the NAS using `cat ... | ssh ... "cat > ..."`
- preserve an existing remote `.env` unless `--update-env` is explicitly used
- prefer `../synology-services-private/.../.env.sops`, then local transitional `.env.sops`,
  then local `.env`, then `.env.example`
- auto-detect the Docker binary on Synology
- auto-select direct Docker access vs `sudo -n` vs `sudo`
- run `docker compose pull` and `docker compose up -d`

When editing or adding a new stack, preserve that operator experience unless there is
a strong reason to diverge.

---

## Important Exceptions

Not every stack is identical. Pay attention to these exceptions:

- `hhnas4/gitea-deploy.sh` — host-level wrapper, not a per-service deploy script;
  preserves remote `.env`; supports admin bootstrap flags; syncs Authentik OIDC config;
  syncs committed CA certs needed for outbound TLS trust
- `hhnas4/promtail-deploy.sh` — host-level wrapper for the `promtail/` stack
- `hhnas4/archivebox/deploy.sh` — seeds the Docker volume before startup
- `hhnas4/postgres/deploy.sh` and `hhnas4/dolt/deploy.sh` — ensure the external shared
  Docker network exists before deploy
- `hhnas4/jellyfin/deploy.sh` — validates `JELLYFIN_MEDIA_DIR` on the target host before deploy
- `nas-host-template/deploy.sh` — older template that still uses `scp`; does not match
  newer `hhnas4` conventions exactly

---

## Compose Conventions

Compose files in this repo are intentionally simple and explicit:

- pinned image tags are preferred; some images are pinned by digest
- explicit `container_name` is common
- `restart: unless-stopped` is the default pattern
- service config usually comes from `.env`
- ports are published directly rather than hidden behind extra tooling
- stateful services often use named volumes on Synology instead of bind mounts

Do not casually replace named volumes with bind mounts. Synology ACL behavior can make
bind mounts look non-writable to non-root container users.

---

## Secrets And Env Files

Rules:

- Never commit plaintext secrets
- Prefer the sibling private repo's `.env.sops` as the tracked secret source
- Use `.env.example` for sanitized defaults and documentation
- Plaintext `.env` files are not blanket-ignored; treat any such file as a visible local
  exception that should be moved out, encrypted, or deleted
- Respect the deploy-script behavior that keeps existing remote `.env` files unless
  `--update-env` is requested
- Private continuity notes, real hostnames, real internal IPs, and operator-specific
  Synology workflow belong in `../synology-services-private`, not in public docs or notes here

If a stack already supports `sops`, preserve that workflow.

---

## Synology-Specific Constraints

### Docker bridge egress and firewall behavior

Some containers on Synology can lose LAN/DNS access because DSM firewall chains drop
Docker bridge traffic before normal Docker forwarding rules apply.

Read before making networking changes:

- `hhnas4/docs/DOCKER_ADDRESS_POOL_RUNBOOK.md`
- `hhnas4/docs/GITEA_NAS_PLACEMENT_AND_BRIDGE_EGRESS_FIX_2026-03-05.md`
- `hhnas4/ensure-docker-bridge-lan-egress.sh`

If a service has DNS failures or cannot reach LAN-hosted dependencies, check
bridge-egress policy before assuming the app config is wrong.

### Reverse proxy model

Several apps are intentionally loopback-only and sit behind the Synology DSM reverse
proxy. Common pattern: app binds to `127.0.0.1:<port>` on the NAS; DSM terminates TLS
and proxies to loopback.

Do not widen bindings to `0.0.0.0` unless the service actually needs direct LAN clients.

### Docker binary path and privileges

On Synology, Docker may live at:

- `docker`
- `/usr/local/bin/docker`
- `/var/packages/ContainerManager/target/usr/bin/docker`
- `/var/packages/Docker/target/usr/bin/docker`

Existing scripts already handle this. Preserve that logic when possible.

---

## Validation Expectations

Typical validations in this repo:

- `docker compose ps`
- short `curl` probes against loopback or reverse-proxied endpoints
- log checks with `docker compose logs --tail ...`
- connectivity checks to shared infra services

If you add a new stack or materially change an existing one, update the relevant README
validation guidance too.

---

## Documentation Expectations

When behavior changes, update the nearest relevant docs:

- top-level or host README when entrypoints or host scope change
- stack README when runtime model, ports, storage, dependencies, or validation change
- host runbooks when operational procedures change
- `hhnas4/docs/SESSION_NOTES.md` for host-level continuity when the change affects ongoing operations
- if those continuity notes need real hostnames or operator-specific workflow, write them in
  `../synology-services-private` instead and keep only the sanitized version here

---

## Backup And Operations

Shared stateful infrastructure backups are documented and scripted:

- `hhnas4/backup-shared-infra.sh`
- `hhnas4/docs/SHARED_INFRA_BACKUP_RUNBOOK.md`

Do not invent a parallel backup workflow for Postgres/MySQL/Redis without a clear reason.

---

## Working Rules

- Read Markdown first, then implementation
- Enter `nix develop` before committing or pushing — pre-hook tools (`prek`, `gitleaks`,
  `markdownlint-cli2`, `shellcheck`, `shfmt`, `sops`) are only available in the dev shell
- Never use `--no-verify` to bypass missing local tools; enter `nix develop` and rerun instead
- At the start of a session: `git fetch origin`, then `git pull --rebase origin main`
- Prefer `rg` for discovery
- Avoid destructive Docker or git cleanup unless explicitly requested
- When the task is finished, commit and push to `origin` unless the user wants changes kept local
- If the task changes service behavior, run the owning Synology deploy after push and verify
  on the live host
- Run `nix run .#session-preflight` before meaningful implementation work
