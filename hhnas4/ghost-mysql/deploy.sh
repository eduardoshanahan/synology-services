#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  deploy.sh [target-host] [target-dir]

Examples:
  ./deploy.sh nas-host
  ./deploy.sh nas-host /volume1/docker/homelab/nas-host/ghost-mysql
USAGE
}

TARGET_HOST="nas-host.internal.example"
TARGET_DIR="/volume1/docker/homelab/nas-host/ghost-mysql"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ "${1:-}" != "" && "${1:-}" != --* ]]; then
  TARGET_HOST="$1"
  shift
fi

if [[ "${1:-}" != "" && "${1:-}" != --* ]]; then
  TARGET_DIR="$1"
  shift
fi

if [[ $# -gt 0 ]]; then
  echo "[deploy] unknown argument: $1" >&2
  usage >&2
  exit 2
fi

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REMOTE_COMPOSE_FILE="${TARGET_DIR}/compose.yaml"
REMOTE_ENV_FILE="${TARGET_DIR}/.env"

echo "[deploy] target host: ${TARGET_HOST}"
echo "[deploy] target dir : ${TARGET_DIR}"

ssh "${TARGET_HOST}" "mkdir -p '${TARGET_DIR}'"

cat "${SRC_DIR}/compose.yaml" | ssh "${TARGET_HOST}" "cat > '${REMOTE_COMPOSE_FILE}'"

if ssh "${TARGET_HOST}" "test ! -f '${REMOTE_ENV_FILE}'"; then
  cat "${SRC_DIR}/.env.example" | ssh "${TARGET_HOST}" "cat > '${REMOTE_ENV_FILE}'"
  echo "[deploy] created ${REMOTE_ENV_FILE} from template"
else
  echo "[deploy] keeping existing ${REMOTE_ENV_FILE}"
fi

DOCKER_BIN="$(ssh "${TARGET_HOST}" "command -v docker || { test -x /usr/local/bin/docker && echo /usr/local/bin/docker; } || { test -x /var/packages/ContainerManager/target/usr/bin/docker && echo /var/packages/ContainerManager/target/usr/bin/docker; } || { test -x /var/packages/Docker/target/usr/bin/docker && echo /var/packages/Docker/target/usr/bin/docker; }")"

if [[ -z "${DOCKER_BIN}" ]]; then
  echo "[deploy] could not find docker binary on ${TARGET_HOST}" >&2
  exit 1
fi

if ssh "${TARGET_HOST}" "${DOCKER_BIN} info >/dev/null 2>&1"; then
  DOCKER_PREFIX=""
elif ssh "${TARGET_HOST}" "sudo -n ${DOCKER_BIN} info >/dev/null 2>&1"; then
  DOCKER_PREFIX="sudo -n "
else
  DOCKER_PREFIX="sudo "
fi

ssh "${TARGET_HOST}" "cd '${TARGET_DIR}' && ${DOCKER_PREFIX}${DOCKER_BIN} compose pull && ${DOCKER_PREFIX}${DOCKER_BIN} compose up -d"

echo "[deploy] ghost-mysql deployed. Verify with:"
echo "         ssh ${TARGET_HOST} \"cd '${TARGET_DIR}' && ${DOCKER_PREFIX}${DOCKER_BIN} compose ps\""
echo "         ssh ${TARGET_HOST} \"cd '${TARGET_DIR}' && ${DOCKER_PREFIX}${DOCKER_BIN} compose ps --format json\""
echo "         ssh ${TARGET_HOST} \"cd '${TARGET_DIR}' && ${DOCKER_PREFIX}${DOCKER_BIN} compose logs --tail 40\""
