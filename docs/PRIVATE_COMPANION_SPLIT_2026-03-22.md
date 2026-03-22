# `synology-services` Private Companion Split - 2026-03-22

## Decision

`synology-services` now uses a sibling private companion directory:

- `../synology-services-private/`

This replaces the previous in-repo tracked `.env.sops` model for active stacks.

## New env resolution order

For stacks that manage env files through the deploy scripts, the source order is
now:

1. `../synology-services-private/<stack>/.env.sops`
2. local transitional `<stack>/.env.sops`
3. local `<stack>/.env`
4. existing remote NAS-side `.env`
5. tracked `<stack>/.env.example`

The remote NAS-side `.env` is still preserved by default. Operators only push a
new env file when they explicitly use `--update-env`.

Plaintext local `.env` files are no longer blanket-ignored in Git. If one is
present, it is meant to be visible in `git status` until it is moved, encrypted,
or deleted.

## Files moved

Tracked encrypted env sources moved out of the public repo for:

- `nas-host/dolt`
- `nas-host/jellyfin`
- `nas-host/karakeep`
- `nas-host/mongo`
- `nas-host/mysql`
- `nas-host/outline`
- `nas-host/paperless`
- `nas-host/postgres`
- `nas-host/qbittorrent`
- `nas-host/redis`
- `nas-host/woodpecker-agent`

## Deploy script changes

The following stacks now resolve the sibling private repo automatically:

- `mongo`
- `postgres`
- `redis`
- `tika`
- `gotenberg`
- `dolt`
- `karakeep`
- `paperless`
- `outline`
- `jellyfin`
- `qbittorrent`
- `mysql`
- `woodpecker-agent`
- `gitea-deploy.sh`

Additionally, `mysql`, `woodpecker-agent`, and `gitea-deploy.sh` now support
`--update-env` to align with the common stack contract.
