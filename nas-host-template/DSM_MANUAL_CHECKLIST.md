# Synology DSM Manual Checklist

This checklist covers the DSM UI actions that are not currently automatable in this repository.

## 1. Confirm node-exporter is reachable

1. In DSM, open **Container Manager** and verify `node-exporter` is running.
2. From LAN, verify `http://<nas-fqdn>:9100/metrics` responds.
3. In Prometheus UI, confirm target `<nas-fqdn>:9100` is `UP` under job `synology-nodes`.

## 2. Configure DSM log forwarding to Loki path

1. Open **Log Center** -> **Log Sending**.
2. Create a sending rule with:
   - Protocol: `TCP`
   - Destination server: `<logs-node-lan-ip>` (or `loki.internal.example`)
   - Destination port: `1514`
3. Include file-service/security events (SMB/NFS/AFP/auth/file operations).
4. Save and use **Send test log**.
5. In Grafana Explore (Loki datasource), verify:
   - `{job="synology-file-activity"}`

## 3. Verify dashboards

1. Grafana -> folder `Homelab` -> dashboard `NAS Detail`.
2. Grafana -> folder `Homelab` -> dashboard `NAS File Activity`.
3. Confirm panels show data for your NAS host.
