# Gitea Operations Checklist (nas-host)

Purpose: post-deploy configuration and recurring checks for Gitea + registry.

## 1) Access & account safety

- [ ] Confirm admin login works at `https://gitea.internal.example`.
- [ ] Enable 2FA on admin account.
- [ ] Create a non-admin day-to-day user.
- [ ] Keep admin account for maintenance only.

## 2) Security defaults

- [ ] Verify registration is disabled (unless intentionally opened):
  - `GITEA_DISABLE_REGISTRATION=true`
- [ ] Set default repo visibility policy as desired (private-by-default is recommended).
- [ ] Configure branch protections on important repositories.

## 3) SSH & Git workflow

- [ ] Upload SSH key in Gitea user settings.
- [ ] Verify auth:
  - `ssh -p 2222 -T git@gitea.internal.example`
- [ ] Optional local SSH config:

```sshconfig
Host gitea-hhlab
  HostName gitea.internal.example
  Port 2222
  User git
  IdentityFile ~/.ssh/<your_key>
  IdentitiesOnly yes
```

## 4) Container registry validation

- [ ] Login to registry:
  - `docker login gitea.internal.example`
- [ ] Push a test image:
  - `docker tag alpine:latest gitea.internal.example/<owner>/alpine-test:latest`
  - `docker push gitea.internal.example/<owner>/alpine-test:latest`
- [ ] Pull it back from another machine to verify read path.

## 5) Backups

- [ ] Back up Gitea data path:
  - `/volume1/docker/homelab/nas-host/gitea/data`
- [ ] Add scheduled backup (daily recommended).
- [ ] Periodically test restore in a disposable environment.

## 6) Email/notifications (recommended)

- [ ] Configure SMTP in Gitea admin settings.
- [ ] Test password reset email delivery.
- [ ] Confirm notification emails are sent for watched repos/issues.

## 7) Health checks

- [ ] HTTPS check:
  - `curl -skI https://gitea.internal.example/`
- [ ] Backend check on NAS:
  - `curl -sSI http://127.0.0.1:3000/`
- [ ] Compose status on NAS:
  - `cd /volume1/docker/homelab/nas-host/gitea && sudo /usr/local/bin/docker compose ps`

## 8) Upgrade process

- [ ] Update image tag in `gitea/compose.yaml`.
- [ ] Deploy with `./gitea-deploy.sh`.
- [ ] If needed, deploy log shipping with `./promtail-deploy.sh`.
- [ ] Re-run health checks and SSH/registry smoke tests.

## Daily commands (copy/paste)

### Git over SSH

```bash
# SSH auth probe (expected: success message, no shell)
ssh -p 2222 -T git@gitea.internal.example

# Clone
git clone ssh://git@gitea.internal.example:2222/<owner>/<repo>.git

# Existing repo remote
git remote set-url origin ssh://git@gitea.internal.example:2222/<owner>/<repo>.git
```

### Container registry

```bash
# Login
docker login gitea.internal.example

# Tag + push test image
docker pull alpine:latest
docker tag alpine:latest gitea.internal.example/<owner>/alpine-test:latest
docker push gitea.internal.example/<owner>/alpine-test:latest

# Pull back
docker pull gitea.internal.example/<owner>/alpine-test:latest
```

### Quick health checks

```bash
# Public HTTPS path
curl -skI https://gitea.internal.example/ | head -n 5

# SSH endpoint reachability
ssh -o BatchMode=yes -o ConnectTimeout=8 -p 2222 -T git@gitea.internal.example

# NAS backend + compose
ssh nas-host "curl -sSI http://127.0.0.1:3000/ | head -n 5"
ssh nas-host "cd /volume1/docker/homelab/nas-host/gitea && sudo /usr/local/bin/docker compose ps"

# Promtail shipping status on NAS
ssh nas-host "curl -sSI http://127.0.0.1:9080/ready | head -n 5"
ssh nas-host "cd /volume1/docker/homelab/nas-host/promtail && sudo /usr/local/bin/docker compose ps"
```
