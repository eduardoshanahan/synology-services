# ArchiveBox (hhnas4)

Dedicated ArchiveBox stack for large local archival storage on `hhnas4`.

## Purpose

- Runs ArchiveBox directly on the Synology host.
- Keeps the full `/data` tree local to the NAS, including `index.sqlite3`.
- Avoids remote SQLite I/O from a Raspberry Pi mount.
- Uses a Docker-managed named volume because this Synology host exposes bind
  mounts as read-only to ArchiveBox's required non-root runtime user.
- Uses bridge networking with an explicit host port publish
  (`${ARCHIVEBOX_HOST_BIND}:${ARCHIVEBOX_PORT}:8000`).

## Layout

- `compose.yaml`
- `.env.example`
- `deploy.sh`

## Runtime storage on NAS

Default target directory:

```text
/volume1/docker/homelab/hhnas4/archivebox
```

Docker-managed persistent volume:

```text
archivebox_data
```

## Deploy

From this repository:

```bash
cd hhnas4/archivebox
./deploy.sh hhnas4.internal.example
```

Optional target directory override:

```bash
./deploy.sh hhnas4.internal.example /volume1/docker/homelab/hhnas4/archivebox
```

## First-start rules

- Edit `.env` on the NAS before first production start if you need a different port,
  timezone, or search backend.
- The default template binds ArchiveBox inside the container to `0.0.0.0:8000`
  and publishes only on host loopback (`127.0.0.1:${ARCHIVEBOX_PORT}`), and sets
  `ARCHIVEBOX_ALLOWED_HOSTS=archivebox.internal.example`, which is the intended
  shape when it sits behind the DSM reverse proxy.
- Keep `ARCHIVEBOX_HOST_BIND=127.0.0.1` when using the DSM reverse proxy.
- `CHROME_USER_DATA_DIR` defaults to `/data/chrome-profile`, which lets the
  Chromium-based extractors reuse a persistent browser profile stored inside the
  ArchiveBox data volume.
- `COOKIES_FILE` is optional. When set (for example to `/data/cookies.txt`),
  ArchiveBox will use that exported cookie jar for fetches that support it.
- `deploy.sh` now seeds the ArchiveBox Docker volume before first start:
  - creates `${CHROME_USER_DATA_DIR}/Default` when `CHROME_USER_DATA_DIR` is
    under `/data`
  - creates `COOKIES_FILE` when it is set under `/data`
  - applies the configured `PUID`/`PGID`
- The default `ripgrep` search backend is correct when all ArchiveBox data stays
  local on `hhnas4`.
- If you later move only `/data/archive` to remote storage, switch the search
  backend away from `ripgrep`.
- The container starts with `server --quick-init`, which bootstraps the data
  directory automatically on first launch.
- This stack uses a named volume intentionally. A direct bind mount on `hhnas4`
  exposed the path as non-writable to ArchiveBox's non-root user inside the
  container, causing startup failures.
- The compose image is pinned by digest for reproducibility.

## Post-deploy bootstrap

Create an admin user after the container is healthy:

```bash
ssh hhnas4 "cd /volume1/docker/homelab/hhnas4/archivebox && sudo docker compose exec --user archivebox archivebox /bin/bash -lc 'archivebox manage createsuperuser'"
```

Then open the UI through the reverse proxy and complete any application-level
settings there.

## Reverse Proxy (DSM)

Recommended public shape:

- Client URL: `https://archivebox.internal.example/`
- DSM reverse proxy backend: `http://127.0.0.1:8000`

Keep TLS termination in DSM. ArchiveBox itself should continue serving plain
HTTP on loopback only.

## Capture Notes

- This image is missing `single-file`, `readability-extractor`, and
  `postlight-parser`, so `singlefile`, `readability`, and `mercury` extractors
  fail by default unless you install extra dependencies or disable them.
- The current live instance is tuned for lower-identifiability captures:
  - browser-like user agents (no `ArchiveBox/...` suffix)
  - `SAVE_HEADERS=False`
  - `SAVE_WARC=False`
  - `SAVE_ARCHIVE_DOT_ORG=False`
  - `SAVE_MEDIA=False`
- Dynamic sites such as TikTok rely on the Chromium-based extractors (`dom`,
  `screenshot`, `pdf`). Plain `wget` often fails there.
- If a site shows a consent overlay (for example a "Got it" banner), ArchiveBox
  will not click it automatically. The practical workaround is to warm the
  persistent Chromium profile once so the consent cookie/state is saved under
  `CHROME_USER_DATA_DIR`, then re-run the capture.
- The lower-friction workaround is often a cookie export:
  - dismiss the banner in your normal browser,
  - export cookies in Netscape cookie-jar format,
  - place the file in the ArchiveBox data volume (for example
    `/data/cookies.txt`),
  - set `COOKIES_FILE=/data/cookies.txt`,
  - then re-run the capture.

## Validation goals

- Container stays up after the initial quick init.
- `curl -sSI -H 'Host: archivebox.internal.example' http://127.0.0.1:8000/`
  returns a redirect or page response.
- `curl -skI https://archivebox.internal.example/` returns a redirect or page
  response through the DSM reverse proxy.
- Adding a small test URL creates files under the `archivebox_data` volume.
- The archive persists after a container restart.
