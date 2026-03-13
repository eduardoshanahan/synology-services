#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat <<'USAGE'
Usage:
  ./deploy.sh [target-host] [target-dir] [--update-env]

Examples:
  ./deploy.sh nas-host
  ./deploy.sh nas-host /volume1/docker/homelab/nas-host/qbittorrent
  ./deploy.sh nas-host --update-env
USAGE
}

TARGET_HOST="nas-host.internal.example"
TARGET_DIR="/volume1/docker/homelab/nas-host/qbittorrent"
UPDATE_ENV=0

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

while [[ $# -gt 0 ]]; do
	case "$1" in
	--update-env)
		UPDATE_ENV=1
		shift
		;;
	*)
		echo "[deploy] unknown argument: $1" >&2
		usage >&2
		exit 2
		;;
	esac
done

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REMOTE_COMPOSE_FILE="${TARGET_DIR}/compose.yaml"
REMOTE_ENV_FILE="${TARGET_DIR}/.env"
LOCAL_ENV_FILE="${SRC_DIR}/.env"
LOCAL_SOPS_ENV_FILE="${SRC_DIR}/.env.sops"

echo "[deploy] target host: ${TARGET_HOST}"
echo "[deploy] target dir : ${TARGET_DIR}"

ssh "${TARGET_HOST}" "mkdir -p '${TARGET_DIR}'"

cat "${SRC_DIR}/compose.yaml" | ssh "${TARGET_HOST}" "cat > '${REMOTE_COMPOSE_FILE}'"

if [[ -f "${LOCAL_SOPS_ENV_FILE}" ]]; then
	SOPS_BIN="$(command -v sops || true)"
	if [[ -z "${SOPS_BIN}" ]]; then
		echo "[deploy] ${LOCAL_SOPS_ENV_FILE} exists but sops is not installed." >&2
		echo "[deploy] enter 'nix develop' in synology-services (or install sops) and retry." >&2
		exit 1
	fi
fi

if ((UPDATE_ENV)); then
	if [[ -f "${LOCAL_SOPS_ENV_FILE}" ]]; then
		sops -d --input-type dotenv --output-type dotenv "${LOCAL_SOPS_ENV_FILE}" |
			ssh "${TARGET_HOST}" "cat > '${REMOTE_ENV_FILE}'"
		echo "[deploy] updated ${REMOTE_ENV_FILE} from ${LOCAL_SOPS_ENV_FILE}"
	elif [[ -f "${LOCAL_ENV_FILE}" ]]; then
		cat "${LOCAL_ENV_FILE}" | ssh "${TARGET_HOST}" "cat > '${REMOTE_ENV_FILE}'"
		echo "[deploy] updated ${REMOTE_ENV_FILE} from local .env"
	else
		echo "[deploy] --update-env was set but no ${LOCAL_SOPS_ENV_FILE} or ${LOCAL_ENV_FILE} exists." >&2
		exit 1
	fi
elif ssh "${TARGET_HOST}" "test ! -f '${REMOTE_ENV_FILE}'"; then
	if [[ -f "${LOCAL_SOPS_ENV_FILE}" ]]; then
		sops -d --input-type dotenv --output-type dotenv "${LOCAL_SOPS_ENV_FILE}" |
			ssh "${TARGET_HOST}" "cat > '${REMOTE_ENV_FILE}'"
		echo "[deploy] created ${REMOTE_ENV_FILE} from ${LOCAL_SOPS_ENV_FILE}"
	elif [[ -f "${LOCAL_ENV_FILE}" ]]; then
		cat "${LOCAL_ENV_FILE}" | ssh "${TARGET_HOST}" "cat > '${REMOTE_ENV_FILE}'"
		echo "[deploy] created ${REMOTE_ENV_FILE} from local .env"
	else
		cat "${SRC_DIR}/.env.example" | ssh "${TARGET_HOST}" "cat > '${REMOTE_ENV_FILE}'"
		echo "[deploy] created ${REMOTE_ENV_FILE} from template"
	fi
else
	echo "[deploy] keeping existing ${REMOTE_ENV_FILE}"
fi

DOWNLOADS_DIR="$(ssh "${TARGET_HOST}" "grep '^QBITTORRENT_DOWNLOADS_DIR=' '${REMOTE_ENV_FILE}' | cut -d= -f2-")"
if [[ -z "${DOWNLOADS_DIR}" ]]; then
	echo "[deploy] QBITTORRENT_DOWNLOADS_DIR is missing in ${REMOTE_ENV_FILE}" >&2
	exit 1
fi

SERVER_DOMAINS="$(ssh "${TARGET_HOST}" "grep '^QBITTORRENT_SERVER_DOMAINS=' '${REMOTE_ENV_FILE}' | cut -d= -f2-")"
HOST_HEADER_VALIDATION="$(ssh "${TARGET_HOST}" "grep '^QBITTORRENT_HOST_HEADER_VALIDATION=' '${REMOTE_ENV_FILE}' | cut -d= -f2-")"
REVERSE_PROXY_SUPPORT="$(ssh "${TARGET_HOST}" "grep '^QBITTORRENT_REVERSE_PROXY_SUPPORT=' '${REMOTE_ENV_FILE}' | cut -d= -f2-")"
TRUSTED_REVERSE_PROXIES="$(ssh "${TARGET_HOST}" "grep '^QBITTORRENT_TRUSTED_REVERSE_PROXIES=' '${REMOTE_ENV_FILE}' | cut -d= -f2-")"

ssh "${TARGET_HOST}" "mkdir -p '${DOWNLOADS_DIR}'"

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

if [[ -n "${SERVER_DOMAINS}" ]]; then
	ssh "${TARGET_HOST}" \
		"QBITTORRENT_SERVER_DOMAINS='${SERVER_DOMAINS}' \
QBITTORRENT_HOST_HEADER_VALIDATION='${HOST_HEADER_VALIDATION:-true}' \
QBITTORRENT_REVERSE_PROXY_SUPPORT='${REVERSE_PROXY_SUPPORT:-true}' \
QBITTORRENT_TRUSTED_REVERSE_PROXIES='${TRUSTED_REVERSE_PROXIES:-127.0.0.1;::1}' \
QBITTORRENT_CONTAINER_NAME='nas-host-qbittorrent' \
${DOCKER_PREFIX}${DOCKER_BIN} exec nas-host-qbittorrent python3 -c \"from pathlib import Path; import os; p = Path('/config/qBittorrent/qBittorrent.conf'); lines = p.read_text().splitlines(); updates = {'WebUI\\\\ServerDomains': os.environ['QBITTORRENT_SERVER_DOMAINS'], 'WebUI\\\\HostHeaderValidation': os.environ['QBITTORRENT_HOST_HEADER_VALIDATION'].lower(), 'WebUI\\\\ReverseProxySupportEnabled': os.environ['QBITTORRENT_REVERSE_PROXY_SUPPORT'].lower(), 'WebUI\\\\TrustedReverseProxiesList': os.environ['QBITTORRENT_TRUSTED_REVERSE_PROXIES']}; out = []; seen = set();\nfor line in lines:\n    replaced = False\n    for key, value in updates.items():\n        if line.startswith(key + '='):\n            out.append(f'{key}={value}'); seen.add(key); replaced = True; break\n    if not replaced:\n        out.append(line)\nfor key, value in updates.items():\n    if key not in seen:\n        out.append(f'{key}={value}')\np.write_text('\\n'.join(out) + '\\n')\" && ${DOCKER_PREFIX}${DOCKER_BIN} restart nas-host-qbittorrent >/dev/null"
fi

echo "[deploy] qbittorrent deployed. Verify with:"
echo "         ssh ${TARGET_HOST} \"cd '${TARGET_DIR}' && ${DOCKER_PREFIX}${DOCKER_BIN} compose ps\""
echo "         ssh ${TARGET_HOST} \"cd '${TARGET_DIR}' && ${DOCKER_PREFIX}${DOCKER_BIN} compose logs --tail 80\""
echo "         ssh ${TARGET_HOST} \"curl -sS -m 6 -I http://127.0.0.1:\$(grep '^QBITTORRENT_WEBUI_PORT=' '${REMOTE_ENV_FILE}' | cut -d= -f2) | sed -n '1,12p'\""
