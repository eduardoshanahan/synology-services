# Synology Services Repository Split Plan

## Goal

Move `nix-services/synology-services/` into its own Git repository while keeping:

- the current Synology deployment model intact
- the current NAS runtime paths intact
- Gitea on `hhnas4` unaffected

This is a source-control and workspace boundary change, not a runtime redesign.

## Safety Boundary

The live Gitea runtime is on the NAS, not in this repository.

Current runtime paths on `hhnas4`:

- `/volume1/docker/homelab/hhnas4/gitea/compose.yaml`
- `/volume1/docker/homelab/hhnas4/gitea/.env`
- `/volume1/docker/homelab/hhnas4/gitea/data`
- `/volume1/docker/homelab/hhnas4/promtail/compose.yaml`
- `/volume1/docker/homelab/hhnas4/promtail/.env`
- `/volume1/docker/homelab/hhnas4/promtail/config.yml`

Do not change these paths during the repository split.

## Why This Works

`hhnas4/deploy.sh` resolves source files relative to the script location:

- `SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`

That means the deploy logic is self-contained as long as the internal layout stays the same after the move.

## Target Layout

Recommended sibling-repo layout under the same parent workspace:

```text
hhlab-insfrastructure/
  nix-pi/                # Git repo
  nix-services/          # Git repo
  synology-services/     # New Git repo
```

No parent `flake.nix` is required for this split.

## Files To Move As-Is

Move the full tree unchanged:

```text
synology-services/
  README.md
  hhnas4/
    GITEA_OPERATIONS_CHECKLIST.md
    README.md
    SESSION_NOTES.md
    deploy.sh
    archivebox/
      .env.example
      README.md
      compose.yaml
      deploy.sh
    mysql/
      .env.example
      README.md
      compose.yaml
      deploy.sh
    outline/
      .env.example
      README.md
      compose.yaml
      deploy.sh
    gitea/
      .env.example
      compose.yaml
    promtail/
      .env.example
      compose.yaml
      config.yml
  nas-host-template/
    DSM_MANUAL_CHECKLIST.md
    README.md
    deploy.sh
    node-exporter/
      .env.example
      compose.yaml
```

Keep all filenames and all relative paths exactly as they are for the first cut.

## References To Update In `nix-services`

These docs currently assume `synology-services` lives inside `nix-services`:

- `nix-services/documentation_unification_block_1.md`
- `nix-services/ghost_internal_blog_session_handoff_2026-02-27.md`
- `nix-services/synology_monitoring_logs_plan.md`

After the split, these should refer to the external sibling repo explicitly, for example:

- `../synology-services/...` if describing workspace-relative paths
- or plain `synology-services repository` if you want docs to be clone-location agnostic

## References To Update Inside `synology-services`

These docs currently use commands like `cd synology-services/...` because they assume they are being run from inside `nix-services`:

- `synology-services/nas-host-template/README.md`
- `synology-services/hhnas4/README.md`
- `synology-services/hhnas4/archivebox/README.md`
- `synology-services/hhnas4/mysql/README.md`
- `synology-services/hhnas4/SESSION_NOTES.md`

After the split, update those commands to repo-root-relative usage, for example:

- `cd hhnas4`
- `cd hhnas4/archivebox`
- `cd nas-host-template`

or use explicit wording:

- `From the synology-services repository root:`

## Recommended Git Migration Sequence

1. Create a new sibling directory for the new repo.
2. Copy or move `nix-services/synology-services/` into that directory without changing contents.
3. Initialize the new Git repo there.
4. Commit the moved files in the new repo.
5. Update path references in the new repo docs.
6. Update cross-references in `nix-services`.
7. Leave a pointer in `nix-services` temporarily instead of deleting immediately.
8. Validate one no-op deployment check path for Gitea before removing the old copy.

## Low-Risk Transitional State

For the first transition, keep a stub directory in `nix-services`:

```text
nix-services/synology-services/
  README.md
```

That README should say:

- this content moved to the sibling `synology-services` repository
- the old embedded path is retired
- operators should run Synology deploy scripts from the new repo

This reduces broken links and lowers the chance of muscle-memory mistakes.

## Gitea-Specific Validation Checklist

Before deleting the old embedded copy, validate from the new repo:

1. `cd synology-services/hhnas4`
2. Review that `deploy.sh` still sees:
   - `gitea/compose.yaml`
   - `gitea/.env.example`
   - `promtail/compose.yaml`
   - `promtail/.env.example`
   - `promtail/config.yml`
3. Run a dry operational check without changing NAS paths:
   - verify target host and target base arguments remain the same
4. If you choose to redeploy from the new repo, verify after deploy:
   - HTTPS responds
   - SSH on port `2222` responds
   - `docker compose ps` is healthy on the NAS

Suggested checks:

```bash
ssh hhnas4 "cd /volume1/docker/homelab/hhnas4/gitea && sudo /usr/local/bin/docker compose ps"
ssh hhnas4 "curl -sSI http://127.0.0.1:3000/ | head -n 5"
ssh -o BatchMode=yes -o ConnectTimeout=8 -p 2222 -T git@gitea.internal.example
curl -skI https://gitea.internal.example/ | head -n 5
```

## Things Not To Change During The Split

Do not combine the repository split with any of these:

- Gitea image upgrades
- `.env` template changes
- NAS directory changes
- DSM reverse proxy changes
- SSH endpoint changes
- Promtail config changes

One axis at a time.

## Next Change After The Split

Once the new repo exists and the references are updated:

- either remove the embedded `nix-services/synology-services/` copy
- or keep only the pointer README for one transition cycle, then remove it

The safer option is the pointer README first, full removal second.
