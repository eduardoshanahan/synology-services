# `synology-services` Private State Audit - 2026-03-21

## Purpose

This audit determines whether `synology-services` currently needs a sibling
private companion repository similar to:

- `nix-cluster-private`
- `nix-pi-private`

The goal is to document the actual private-state model used by the Synology
stacks and avoid forcing the companion-repo pattern onto a repo that already
has a different explicit contract.

## Scope

This audit reviewed:

- `README.md`
- `AGENTS.md`
- `nas-host/README.md`
- representative stack READMEs
- representative deploy scripts under `nas-host/*/deploy.sh`
- tracked `.env.sops` usage across the active stacks

## Current finding

As of 2026-03-21:

- `synology-services` does **not** currently need a sibling private companion
  repository
- the repo already has an explicit private-state model based on:
  - sanitized `.env.example`
  - optional tracked encrypted `.env.sops`
  - preserved remote NAS-side `.env`
- deploy scripts already know how to:
  - prefer local `.env.sops`
  - fall back to local `.env`
  - otherwise seed from `.env.example`
  - preserve existing remote `.env` unless `--update-env` is explicitly used

That means the repo already has a clear public/private separation without
needing a second sibling flake or repo for evaluation-time private values.

## Evidence

### 1. The repo is not a Nix evaluation-time config repo

Unlike `nix-cluster` or `nix-pi`, this repository is intentionally a plain
shell-and-Compose deployment repo.

It does not currently:

- evaluate host outputs through a private flake input
- import sibling private modules during Nix evaluation
- depend on path-based hidden files to render public config

### 2. The private contract is already explicit in deploy scripts

Representative deploy scripts such as:

- `nas-host/postgres/deploy.sh`
- `nas-host/mongo/deploy.sh`
- `nas-host/outline/deploy.sh`
- `nas-host/qbittorrent/deploy.sh`
- `nas-host/jellyfin/deploy.sh`

all implement the same basic model:

- define `LOCAL_SOPS_ENV_FILE="${SRC_DIR}/.env.sops"`
- decrypt it with `sops -d` when present
- write or update remote `.env` only when appropriate
- preserve the NAS-side `.env` by default

This is already a durable operator contract.

### 3. Tracked encrypted env files are already in use

Tracked `.env.sops` files currently exist for multiple active stacks, including:

- `nas-host/mysql/.env.sops`
- `nas-host/postgres/.env.sops`
- `nas-host/redis/.env.sops`
- `nas-host/mongo/.env.sops`
- `nas-host/dolt/.env.sops`
- `nas-host/outline/.env.sops`
- `nas-host/paperless/.env.sops`
- `nas-host/karakeep/.env.sops`
- `nas-host/jellyfin/.env.sops`
- `nas-host/qbittorrent/.env.sops`
- `nas-host/woodpecker-agent/.env.sops`

This is a meaningful difference from `nix-pi`'s old broken private model:

- private inputs here are already tracked in encrypted form
- they are not hidden gitignored evaluation-time files

### 4. Remote NAS state is intentionally part of the model

For Synology stacks, the live remote `.env` is not just an implementation
detail. It is part of the operator model.

Important behaviors:

- first deploy may seed from `.env.example`
- later deploys preserve remote `.env`
- `--update-env` is the explicit operator action for pushing local env changes

That means a future sibling private repo would not replace the current model by
itself. The deploy scripts would still need to manage NAS-side `.env` state.

## Decision

Current decision:

- do **not** create `synology-services-private` at this time
- keep using:
  - `.env.example`
  - `.env.sops`
  - remote `.env`
- treat the existing encrypted-env deploy flow as the canonical private-state
  contract for this repo

## What could justify a future `synology-services-private`

Only reconsider this if the repo later grows a different kind of private input,
for example:

1. shared non-secret Synology host data that should be versioned privately but
   does not fit the `.env` model
2. reusable private shell templates or host overlays that apply across multiple
   Synology hosts
3. a future Nix-based layer that introduces evaluation-time private inputs

If that happens, the decision should be revisited explicitly instead of assumed.

## What should remain true even if that happens later

Even with a future private companion repo, these current constraints should
still hold:

- no plaintext secrets in Git
- `.env.example` remains sanitized
- `.env.sops` stays encrypted if used
- remote `.env` preservation remains explicit and operator-controlled
- DSM manual steps remain documented rather than implied

## Practical conclusion

`synology-services` is already using an explicit and workable public/private
split.

It is:

- companion-pattern adjacent
- but not companion-repo dependent

So the cross-repo migration story should record this repo as:

- audited
- not currently needing a sibling private repo
- already following an encrypted-env deployment model instead
