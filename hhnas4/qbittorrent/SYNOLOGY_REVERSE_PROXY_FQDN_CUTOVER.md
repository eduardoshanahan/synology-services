# Synology Reverse Proxy FQDN Cutover for qBittorrent

Date: 2026-03-15

## Goal

Remove the remaining live dependency on the NAS LAN IP for
`qbittorrent.internal.example`.

Status:

- completed on `2026-03-15`

The qBittorrent stack itself can run with:

- `QBITTORRENT_HOST_BIND=127.0.0.1`
- `QBITTORRENT_SERVER_DOMAINS=127.0.0.1;localhost;qbittorrent.internal.example`

Before the cutover, the Synology reverse proxy forwarded
`qbittorrent.internal.example` to:

```text
http://192.0.2.10:8080
```

It was changed to:

```text
http://127.0.0.1:8080
```

After that change, the live qBittorrent env was switched back to loopback bind.

## Current Known Reverse Proxy File

On `nas-host`, the active reverse proxy entry was observed in:

```text
/usr/local/etc/nginx/sites-available/6dd49de8-15c8-4bb0-baf9-dcda8025a9a3.w3conf
```

And exposed via:

```text
/etc/nginx/sites-enabled/server.ReverseProxy.conf
```

Observed stanza:

```nginx
server_name qbittorrent.internal.example ;
...
proxy_pass http://192.0.2.10:8080;
```

## Method Used

The change was made through the Synology DSM UI so the configuration stayed
aligned with how DSM manages reverse proxy entries.

Applied change in DSM:

1. Open DSM.
1. Go to the Reverse Proxy configuration page.
1. Find the entry for `qbittorrent.internal.example`.
1. Change the backend destination from:
   - host: `192.0.2.10`
   - port: `8080`
1. To:
   - host: `127.0.0.1`
   - port: `8080`
1. Save the change.

## Validation After DSM Change

Run these on `nas-host`:

```bash
grep -RIn 'qbittorrent.internal.example\|proxy_pass' /etc/nginx /usr/syno/etc/nginx /usr/local/etc/nginx 2>/dev/null | sed -n '1,120p'
curl -sS -m 6 -I http://127.0.0.1:8080 | sed -n '1,12p'
curl -skI https://qbittorrent.internal.example/ | sed -n '1,12p'
```

Observed outcome:

- direct loopback check returns `HTTP/1.1 200 OK`
- public FQDN check returns `HTTP/2 200`

## qBittorrent Env Cutover

After the Synology reverse proxy backend pointed to `127.0.0.1:8080`, the
repo-managed qBittorrent config that removes the fixed NAS IP:

- `QBITTORRENT_HOST_BIND=127.0.0.1`
- `QBITTORRENT_SERVER_DOMAINS=127.0.0.1;localhost;qbittorrent.internal.example`

was applied from the repo:

```bash
cd /path/to/hhlab-insfrastructure/synology-services
nix develop -c ./nas-host/qbittorrent/deploy.sh nas-host --update-env
```

## Final Validation

From `nas-host`:

```bash
grep '^QBITTORRENT_HOST_BIND=' /volume1/docker/homelab/nas-host/qbittorrent/.env
grep '^QBITTORRENT_SERVER_DOMAINS=' /volume1/docker/homelab/nas-host/qbittorrent/.env
curl -sS -m 6 -I http://127.0.0.1:8080 | sed -n '1,12p'
curl -skI https://qbittorrent.internal.example/ | sed -n '1,12p'
```

From `private-pi-02`:

```bash
curl -skI https://qbittorrent.internal.example/ | sed -n '1,12p'
```

Observed final state:

- qBittorrent is only bound on Synology loopback
- public access still works through `qbittorrent.internal.example`
- the live service no longer depends on the current NAS LAN IP
