# qBittorrent (nas-host)

Torrent downloader stack for `nas-host`, intended to keep active and completed
downloads close to NAS-backed media storage.

## Purpose

- Runs qBittorrent on the Synology host.
- Keeps qBittorrent config in a Docker-managed volume on the NAS.
- Uses a dedicated downloads directory under the shared media tree by default.
- Exposes the Web UI on the NAS loopback by default so DSM reverse proxy can
  front it cleanly.

## Service endpoint

- Suggested DNS name: `qbittorrent.internal.example`
- Default Web UI port in this stack: `8080`
- Default BitTorrent port in this stack: `6881/tcp` and `6881/udp`

## Runtime storage on NAS

Default target directory:

```text
/volume1/docker/homelab/nas-host/qbittorrent
```

Docker-managed persistent volume:

```text
qbittorrent_config
```

Default downloads path exposed read-write inside the container:

```text
/volume1/Media/Downloads/qbittorrent
```

## Layout

- `compose.yaml`
- `.env.example`
- `deploy.sh`

## Deploy

From this repository:

```bash
cd nas-host/qbittorrent
./deploy.sh nas-host.internal.example
```

Optional target directory override:

```bash
./deploy.sh nas-host.internal.example /volume1/docker/homelab/nas-host/qbittorrent
```

If you keep local `.env` (or encrypted `.env.sops`), push it explicitly:

```bash
./deploy.sh nas-host.internal.example --update-env
```

## First-start rules

- Set `QBITTORRENT_DOWNLOADS_DIR` in `.env` if you want a different NAS path.
- Keep `QBITTORRENT_HOST_BIND=127.0.0.1` if you plan to front the Web UI
  through DSM reverse proxy.
- Leave `QBITTORRENT_TORRENT_BIND=0.0.0.0` unless you intentionally want the
  BitTorrent ports bound to a narrower interface.
- If you later want Radarr automatic import from `private-pi-02`, ensure the
  completed-download path lives under the same shared export that the Pi can
  mount. The default `/volume1/Media/Downloads/qbittorrent` is chosen with that
  in mind.
- qBittorrent generates the initial Web UI admin password on first boot; read
  the container logs immediately after first start and rotate the password in
  the UI.
- This stack uses a named volume intentionally. On `nas-host`, direct bind mounts
  for `/config` can appear non-writable to qBittorrent's non-root runtime user
  because of Synology ACL behavior.

## Reverse Proxy (DSM)

Recommended public shape:

- Client URL: `https://qbittorrent.internal.example/`
- DSM reverse proxy backend: `http://127.0.0.1:8080`

Keep TLS termination in DSM. qBittorrent itself should continue serving plain
HTTP on the NAS loopback endpoint.

## Validation goals

- `docker compose ps` shows `nas-host-qbittorrent` running.
- From NAS:
  - `curl -sS -m 6 -I http://127.0.0.1:8080 | sed -n '1,12p'`
  returns an HTTP response.
- On first start, logs show the temporary admin password.
- Through the reverse proxy:
  - `curl -skI https://qbittorrent.internal.example/ | sed -n '1,12p'`
  returns an HTTP response.
