#!/usr/bin/env bash
set -euo pipefail

TARGET_HOST="${1:-nas-a.internal.example}"
TARGET_BASE="${2:-/volume1/docker/homelab/nas-host-template}"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REMOTE_NODE_EXPORTER_DIR="${TARGET_BASE}/node-exporter"

echo "[deploy] target host: ${TARGET_HOST}"
echo "[deploy] target dir : ${REMOTE_NODE_EXPORTER_DIR}"

ssh "${TARGET_HOST}" "mkdir -p '${REMOTE_NODE_EXPORTER_DIR}'"
scp "${SRC_DIR}/node-exporter/compose.yaml" "${TARGET_HOST}:${REMOTE_NODE_EXPORTER_DIR}/compose.yaml"
scp "${SRC_DIR}/node-exporter/.env.example" "${TARGET_HOST}:${REMOTE_NODE_EXPORTER_DIR}/.env"

ssh "${TARGET_HOST}" "cd '${REMOTE_NODE_EXPORTER_DIR}' && docker compose pull && docker compose up -d"

echo "[deploy] node-exporter deployed. Verify with:"
echo "         ssh ${TARGET_HOST} \"curl -sS http://127.0.0.1:9100/metrics | head\""
