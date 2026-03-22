# Synology Public Split And History Rewrite Handoff - 2026-03-22

This document is the continuity handoff for the in-progress split between the
public `synology-services` repo and the private companion
`synology-services-private`.

It is written so a fresh session can resume the work without rediscovering the
state, re-auditing the tree, or guessing which steps are still pending.

## Goal

Target operating model:

- `synology-services` must stay ready for GitHub publication at all times.
- `synology-services-private` holds the private tracked env sources.
- Deploys must continue to work without manual intervention.
- Remote NAS-side `.env` files must still be preserved unless `--update-env` is
  explicitly used.
- Plaintext local `.env` files must not be silently hidden by blanket
  `.gitignore` rules.

## Repos And Current Git State

Workspace root:

- `/path/to/hhlab-insfrastructure`

Public repo:

- `/path/to/hhlab-insfrastructure/synology-services`
- branch: `main`
- current HEAD before local changes: `e2cadbd`
- remotes:
  - `origin = <private-git-remote>`
  - `github = <public-github-remote>`
- `git fetch origin` succeeded on 2026-03-22
- working tree is dirty with the split work and has not been committed

Private repo:

- `/path/to/hhlab-insfrastructure/synology-services-private`
- initialized locally with `git init -b main`
- no commits yet
- no remote configured yet
- `git fetch origin` failed because there is currently no `origin`

## What Was Implemented

### 1. Deploy scripts now resolve a sibling private repo

Added helper:

- `lib/env-source.sh`

It provides the public/private env selection logic used by updated deploy
scripts.

New env resolution order:

1. `../synology-services-private/<stack>/.env.sops`
2. local transitional `<stack>/.env.sops`
3. local `<stack>/.env`
4. existing remote NAS-side `.env`
5. tracked `<stack>/.env.example`

Remote `.env` preservation behavior is unchanged unless `--update-env` is used.

### 2. Updated deploy entrypoints

These scripts were updated to use the new env resolution flow:

- `nas-host/mongo/deploy.sh`
- `nas-host/postgres/deploy.sh`
- `nas-host/redis/deploy.sh`
- `nas-host/tika/deploy.sh`
- `nas-host/gotenberg/deploy.sh`
- `nas-host/dolt/deploy.sh`
- `nas-host/karakeep/deploy.sh`
- `nas-host/paperless/deploy.sh`
- `nas-host/outline/deploy.sh`
- `nas-host/jellyfin/deploy.sh`
- `nas-host/qbittorrent/deploy.sh`
- `nas-host/mysql/deploy.sh`
- `nas-host/woodpecker-agent/deploy.sh`
- `nas-host/gitea-deploy.sh`

Additional alignment:

- `nas-host/mysql/deploy.sh` now supports `--update-env`
- `nas-host/woodpecker-agent/deploy.sh` now supports `--update-env`
- `nas-host/gitea-deploy.sh` now supports `--update-env`

### 3. Tracked encrypted env files were moved to the private repo

Removed from `synology-services` and moved to mirrored paths in
`synology-services-private`:

- `nas-host/dolt/.env.sops`
- `nas-host/jellyfin/.env.sops`
- `nas-host/karakeep/.env.sops`
- `nas-host/mongo/.env.sops`
- `nas-host/mysql/.env.sops`
- `nas-host/outline/.env.sops`
- `nas-host/paperless/.env.sops`
- `nas-host/postgres/.env.sops`
- `nas-host/qbittorrent/.env.sops`
- `nas-host/redis/.env.sops`
- `nas-host/woodpecker-agent/.env.sops`

Current private repo env inventory:

- `nas-host/dolt/.env.sops`
- `nas-host/jellyfin/.env.sops`
- `nas-host/karakeep/.env.sops`
- `nas-host/mongo/.env.sops`
- `nas-host/mysql/.env.sops`
- `nas-host/outline/.env.sops`
- `nas-host/paperless/.env.sops`
- `nas-host/postgres/.env.sops`
- `nas-host/qbittorrent/.env.sops`
- `nas-host/redis/.env.sops`
- `nas-host/woodpecker-agent/.env.sops`

### 4. Plaintext `.env` handling was tightened

Only one plaintext local env file was found in the public repo:

- `nas-host/dolt/.env`

It was moved to the private repo:

- `synology-services-private/nas-host/dolt/.env`

Blanket `**/.env` ignore rules were removed from both repos so plaintext `.env`
files remain visible in `git status`.

Important remaining follow-up:

- `synology-services-private/nas-host/dolt/.env` still exists as plaintext and
  should be converted to `.env.sops` if the goal is zero plaintext env files in
  either repo.

### 5. Public docs and defaults were sanitized

Sanitization work covered:

- public `.env.example` files
- public `compose.yaml` fallback defaults
- current stack READMEs
- historical runbooks and continuity docs that still contained real topology

The goal of this pass was to remove real hostnames, LAN IPs, and similar
topology details from the public working tree.

### 6. New companion repo docs were added

Public repo docs updated or added:

- `README.md`
- `AGENTS.md`
- `PRIVATE_COMPANION_SPLIT_2026-03-22.md`

Private repo docs added:

- `README.md`
- `AGENTS.md`
- `.gitignore`
- `.sops.yaml`

## Validation Already Performed

The following validation passed during the split work:

- `bash -n lib/env-source.sh`
- `bash -n` on all updated deploy scripts
- public tree scan confirmed no remaining local `.env` or `.env.sops` files
  under `synology-services/nas-host`
- private tree scan confirmed the moved env files exist under mirrored paths
- scans for public-facing defaults/docs no longer found the old real topology
  strings in the current working tree

Current quick file reality:

- public repo `find nas-host -maxdepth 2 \( -name '.env.sops' -o -name '.env' \)`
  returns nothing
- private repo equivalent returns the moved `.env.sops` files plus
  `nas-host/dolt/.env`

## Current Uncommitted Public Repo Status

As of this handoff, `synology-services` has uncommitted modifications to:

- `.gitignore`
- `AGENTS.md`
- `README.md`
- many stack READMEs and `.env.example` files
- selected `compose.yaml` files
- the deploy scripts listed above
- host-level runbooks and continuity docs
- deletions for the tracked `.env.sops` files
- new untracked `lib/env-source.sh`
- new untracked `PRIVATE_COMPANION_SPLIT_2026-03-22.md`

Nothing from this split has been committed yet.

## Current Uncommitted Private Repo Status

As of this handoff, `synology-services-private` has no commits and currently
contains only untracked files:

- `.gitignore`
- `.sops.yaml`
- `AGENTS.md`
- `README.md`
- `nas-host/...` mirrored env files

## Important Remaining Blocker: Public History Is Not Clean

The working tree is much cleaner now, but the public repo history is still not
safe for GitHub publication.

### Why history rewrite is still required

Historical commits still contain:

- tracked `.env.sops` files
- real internal topology strings such as `<internal-domain>`
- older machine-local artifacts and references

Concrete evidence gathered during this session:

- current history examples containing tracked env commits:
  - `7e41614 Track Woodpecker agent env`
  - `21c3228 Track MySQL env`
  - `a4f25fc Track Dolt env`
  - `f9e51b7 Track Postgres and Paperless envs`
- current history grep still finds `<internal-domain>` in older revisions of:
  - `nas-host/README.md`
  - `nas-host/SESSION_NOTES.md`
  - `nas-host/GITEA_NAS_PLACEMENT_AND_BRIDGE_EGRESS_FIX_2026-03-05.md`
  - multiple stack READMEs and examples
- old `.direnv` history also existed:
  - `17e9428 Updated environment settings`
  - `55f7573 Remove Nix tooling scaffolding`

This means:

- committing the current working tree is not enough to make the repo public-safe
- if the long-term policy is that `synology-services` should always be ready to
  publish publicly, the repo history must be rewritten before future normal
  dual-push workflow is trusted

## Recommended Next Session Order

This is the safest execution order for the next fresh session.

### Phase 1. Re-check the trees

From the repo roots:

1. `git status --short --branch`
2. `git diff --stat`
3. re-run the current-tree scans for:
   - `<internal-domain>`
   - `<lan-ip-prefix>`
   - `<private-hostname-prefix>`
   - local `.env` and `.env.sops`

### Phase 2. Decide whether to convert the remaining plaintext Dolt env

Status update:

- `synology-services-private/nas-host/dolt/.env` was present as a temporary
  migration artifact.
- it matched the decrypted `.env.sops` content after normalizing blank lines
  and has now been removed
- the public deploy flow still resolves `nas-host/dolt/.env.sops` correctly via
  the mirrored sibling path

### Phase 3. Rewrite `synology-services` history

Use a deliberate history rewrite workflow before any public push.

At minimum, remove from history:

- `**/.env.sops`
- `.direnv/**`
- real hostnames and LAN IP strings in docs/examples/history

Potential approach:

- use `git filter-repo` if available
- otherwise use another reproducible history rewrite tool, but keep the rewrite
  explicit and documented

Important:

- this is a destructive Git operation
- after rewrite, `synology-services` will require force-push to both remotes
- if any other local clones exist, they will need to realign with the rewritten
  history

### Phase 4. Re-run publication safety scans after rewrite

After the history rewrite:

- grep current tree again
- grep full history again
- confirm the old env files, topology strings, and `.direnv` artifacts no
  longer appear in reachable history

### Phase 5. Commit each repo separately

After history is made safe:

For `synology-services`:

- commit the public split changes
- push to `origin`
- push to `github`

For `synology-services-private`:

- add a private remote on Gitea
- make the initial commit
- push to its private remote

## Commands Already Useful In This Session

These commands were useful for auditing and can be reused.

Public repo state:

```bash
git status --short --branch
git remote -v
git log --oneline --decorate --max-count=12
```

Current tree env scan:

```bash
find nas-host -maxdepth 2 \( -name '.env.sops' -o -name '.env' \) | sort
```

History grep for real topology:

```bash
git rev-list --all | xargs -r git grep -n '<internal-domain>'
```

History grep for env references:

```bash
git rev-list --all | xargs -r git grep -n '/.env.sops'
```

History grep for old direnv traces:

```bash
git log --all --oneline -- .direnv
```

## Assumptions To Preserve

These assumptions were used while implementing the split:

- The sibling repo location is fixed at `../synology-services-private` relative
  to `synology-services`.
- Operators want the same deploy ergonomics as before.
- Existing remote NAS-side `.env` files must remain untouched unless
  `--update-env` is explicitly requested.
- Public docs and templates should use placeholder topology, not real homelab
  identifiers.
- The private repo is allowed to exist only on private hosting even if the
  public repo is mirrored to GitHub.

## Open Items

Open items still requiring action:

1. Rewrite `synology-services` history so the repo is actually public-safe.
2. Add a remote to `synology-services-private`.
3. Commit and push both repos once the history question is resolved.

## Bottom Line

The functional public/private split is implemented in the working tree and the
deploy path has been updated to keep operator behavior intact.

The main unresolved issue is not runtime behavior. It is Git history. The
current tree is close to publication-ready, but the existing `synology-services`
history still contains material that should be removed before the repo is
treated as safely public.
