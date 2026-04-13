#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat <<'USAGE'
Usage:
  promtail-deploy.sh [target-host] [target-base]

Examples:
  ./promtail-deploy.sh hhnas4
  ./promtail-deploy.sh hhnas4 /volume1/docker/homelab/hhnas4
USAGE
}

TARGET_HOST="hhnas4.internal.example"
TARGET_BASE="/volume1/docker/homelab/hhnas4"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
	usage
	exit 0
fi

if [[ "${1:-}" != "" && "${1:-}" != --* ]]; then
	TARGET_HOST="$1"
	shift
fi

if [[ "${1:-}" != "" && "${1:-}" != --* ]]; then
	TARGET_BASE="$1"
	shift
fi

if [[ $# -gt 0 ]]; then
	echo "[deploy] unknown argument: $1" >&2
	usage >&2
	exit 2
fi

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REMOTE_PROMTAIL_DIR="${TARGET_BASE}/promtail"
REMOTE_PROMTAIL_COMPOSE_FILE="${REMOTE_PROMTAIL_DIR}/compose.yaml"
REMOTE_PROMTAIL_ENV_FILE="${REMOTE_PROMTAIL_DIR}/.env"
REMOTE_PROMTAIL_CONFIG_FILE="${REMOTE_PROMTAIL_DIR}/config.yml"

echo "[deploy] target host: ${TARGET_HOST}"
echo "[deploy] target dir : ${REMOTE_PROMTAIL_DIR}"

ssh "${TARGET_HOST}" "mkdir -p '${REMOTE_PROMTAIL_DIR}' '${REMOTE_PROMTAIL_DIR}/data'"

cat "${SRC_DIR}/promtail/compose.yaml" | ssh "${TARGET_HOST}" "cat > '${REMOTE_PROMTAIL_COMPOSE_FILE}'"
cat "${SRC_DIR}/promtail/config.yml" | ssh "${TARGET_HOST}" "cat > '${REMOTE_PROMTAIL_CONFIG_FILE}'"

if ssh "${TARGET_HOST}" "test ! -f '${REMOTE_PROMTAIL_ENV_FILE}'"; then
	cat "${SRC_DIR}/promtail/.env.example" | ssh "${TARGET_HOST}" "cat > '${REMOTE_PROMTAIL_ENV_FILE}'"
	echo "[deploy] created ${REMOTE_PROMTAIL_ENV_FILE} from template"
else
	echo "[deploy] keeping existing ${REMOTE_PROMTAIL_ENV_FILE}"
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

ssh "${TARGET_HOST}" "cd '${REMOTE_PROMTAIL_DIR}' && ${DOCKER_PREFIX}${DOCKER_BIN} compose pull && ${DOCKER_PREFIX}${DOCKER_BIN} compose up -d"

echo "[deploy] promtail deployed. Verify with:"
echo "         ssh ${TARGET_HOST} \"cd '${REMOTE_PROMTAIL_DIR}' && ${DOCKER_PREFIX}${DOCKER_BIN} compose ps\""
echo "         ssh ${TARGET_HOST} \"curl -sSI http://127.0.0.1:9080/ready | head -n 1\""
