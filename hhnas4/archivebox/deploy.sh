#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat <<'USAGE'
Usage:
  deploy.sh [target-host] [target-dir]

Examples:
  ./deploy.sh nas-host
  ./deploy.sh nas-host /volume1/docker/homelab/nas-host/archivebox
USAGE
}

TARGET_HOST="nas-host.internal.example"
TARGET_DIR="/volume1/docker/homelab/nas-host/archivebox"

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
PROJECT_NAME="$(basename "${TARGET_DIR}")"
VOLUME_NAME="${PROJECT_NAME}_archivebox_data"

echo "[deploy] target host: ${TARGET_HOST}"
echo "[deploy] target dir : ${TARGET_DIR}"

ssh "${TARGET_HOST}" "mkdir -p '${TARGET_DIR}' '${TARGET_DIR}/data'"

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

PUID="$(ssh "${TARGET_HOST}" "awk -F= '/^PUID=/{print \$2; found=1} END{if(!found) print 911}' '${REMOTE_ENV_FILE}' | tail -n 1")"
PGID="$(ssh "${TARGET_HOST}" "awk -F= '/^PGID=/{print \$2; found=1} END{if(!found) print 911}' '${REMOTE_ENV_FILE}' | tail -n 1")"
CHROME_USER_DATA_DIR="$(ssh "${TARGET_HOST}" "awk -F= '/^CHROME_USER_DATA_DIR=/{print \$2; found=1} END{if(!found) print \"/data/chrome-profile\"}' '${REMOTE_ENV_FILE}' | tail -n 1")"
COOKIES_FILE="$(ssh "${TARGET_HOST}" "awk -F= '/^COOKIES_FILE=/{print \$2; found=1} END{if(!found) print \"\"}' '${REMOTE_ENV_FILE}' | tail -n 1")"

if [[ "${CHROME_USER_DATA_DIR}" == /data/* ]]; then
	SEED_CMD="mkdir -p '${CHROME_USER_DATA_DIR%/}/Default'"
	CHOWN_TARGETS="'${CHROME_USER_DATA_DIR%/}'"
else
	echo "[deploy] warning: CHROME_USER_DATA_DIR='${CHROME_USER_DATA_DIR}' is outside /data; skipping profile seeding" >&2
	SEED_CMD="true"
	CHOWN_TARGETS=""
fi

if [[ -n "${COOKIES_FILE}" ]]; then
	if [[ "${COOKIES_FILE}" == /data/* ]]; then
		SEED_CMD="${SEED_CMD} && mkdir -p '$(dirname "${COOKIES_FILE}")' && touch '${COOKIES_FILE}'"
		CHOWN_TARGETS="${CHOWN_TARGETS} '${COOKIES_FILE}'"
	else
		echo "[deploy] warning: COOKIES_FILE='${COOKIES_FILE}' is outside /data; skipping cookie file seeding" >&2
	fi
fi

if [[ -n "${CHOWN_TARGETS}" ]]; then
	SEED_CMD="${SEED_CMD} && chown -R '${PUID}:${PGID}' ${CHOWN_TARGETS}"
fi

ssh "${TARGET_HOST}" "${DOCKER_PREFIX}${DOCKER_BIN} run --rm -v '${VOLUME_NAME}:/data' busybox sh -lc ${SEED_CMD@Q}"

ssh "${TARGET_HOST}" "cd '${TARGET_DIR}' && ${DOCKER_PREFIX}${DOCKER_BIN} compose pull && ${DOCKER_PREFIX}${DOCKER_BIN} compose up -d"

echo "[deploy] archivebox deployed. Verify with:"
echo "         ssh ${TARGET_HOST} \"cd '${TARGET_DIR}' && ${DOCKER_PREFIX}${DOCKER_BIN} compose ps\""
echo "         ssh ${TARGET_HOST} \"curl -sSI http://127.0.0.1:${ARCHIVEBOX_PORT:-8000}/ | head -n 1\""
echo "         ssh ${TARGET_HOST} \"cd '${TARGET_DIR}' && ${DOCKER_PREFIX}${DOCKER_BIN} compose logs --tail 40\""
