#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat <<'USAGE'
Usage:
  ./deploy.sh [target-host] [target-dir] [--update-env]

Examples:
  ./deploy.sh hhnas4
  ./deploy.sh hhnas4 /volume1/docker/homelab/hhnas4/qbittorrent
  ./deploy.sh hhnas4 --update-env
USAGE
}

TARGET_HOST="hhnas4.internal.example"
TARGET_DIR="/volume1/docker/homelab/hhnas4/qbittorrent"
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
# shellcheck disable=SC1091
source "${SRC_DIR}/../../lib/env-source.sh"
REMOTE_COMPOSE_FILE="${TARGET_DIR}/compose.yaml"
REMOTE_ENV_FILE="${TARGET_DIR}/.env"
LOCAL_ENV_FILE="${SRC_DIR}/.env"
LOCAL_SOPS_ENV_FILE="${SRC_DIR}/.env.sops"
synology_select_sops_env_file "${LOCAL_SOPS_ENV_FILE}"

echo "[deploy] target host: ${TARGET_HOST}"
echo "[deploy] target dir : ${TARGET_DIR}"

ssh "${TARGET_HOST}" "mkdir -p '${TARGET_DIR}'"

cat "${SRC_DIR}/compose.yaml" | ssh "${TARGET_HOST}" "cat > '${REMOTE_COMPOSE_FILE}'"

if [[ -n "${SYN_SELECTED_SOPS_ENV_FILE}" ]]; then
	SOPS_BIN="$(command -v sops || true)"
	if [[ -z "${SOPS_BIN}" ]]; then
		echo "[deploy] ${SYN_SELECTED_SOPS_ENV_FILE} exists but sops is not installed." >&2
		echo "[deploy] enter 'nix develop' in synology-services (or install sops) and retry." >&2
		exit 1
	fi
fi

if ((UPDATE_ENV)); then
	if [[ -n "${SYN_SELECTED_SOPS_ENV_FILE}" ]]; then
		sops -d --input-type dotenv --output-type dotenv "${SYN_SELECTED_SOPS_ENV_FILE}" |
			ssh "${TARGET_HOST}" "cat > '${REMOTE_ENV_FILE}'"
		echo "[deploy] updated ${REMOTE_ENV_FILE} from ${SYN_SELECTED_SOPS_ENV_FILE}"
	elif [[ -f "${LOCAL_ENV_FILE}" ]]; then
		cat "${LOCAL_ENV_FILE}" | ssh "${TARGET_HOST}" "cat > '${REMOTE_ENV_FILE}'"
		echo "[deploy] updated ${REMOTE_ENV_FILE} from local .env"
	else
		echo "[deploy] --update-env was set but no env source exists in ${SYN_PRIVATE_SOPS_ENV_FILE:-<no private companion path>}, ${LOCAL_SOPS_ENV_FILE}, or ${LOCAL_ENV_FILE}." >&2
		exit 1
	fi
elif ssh "${TARGET_HOST}" "test ! -f '${REMOTE_ENV_FILE}'"; then
	if [[ -n "${SYN_SELECTED_SOPS_ENV_FILE}" ]]; then
		sops -d --input-type dotenv --output-type dotenv "${SYN_SELECTED_SOPS_ENV_FILE}" |
			ssh "${TARGET_HOST}" "cat > '${REMOTE_ENV_FILE}'"
		echo "[deploy] created ${REMOTE_ENV_FILE} from ${SYN_SELECTED_SOPS_ENV_FILE}"
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

WEBUI_USERNAME="$(ssh "${TARGET_HOST}" "grep '^QBITTORRENT_WEBUI_USERNAME=' '${REMOTE_ENV_FILE}' | cut -d= -f2-")"
WEBUI_PASSWORD="$(ssh "${TARGET_HOST}" "grep '^QBITTORRENT_WEBUI_PASSWORD=' '${REMOTE_ENV_FILE}' | cut -d= -f2-")"
if [[ -z "${WEBUI_USERNAME}" || -z "${WEBUI_PASSWORD}" ]]; then
	echo "[deploy] qBittorrent Web UI credentials are missing in ${REMOTE_ENV_FILE}" >&2
	exit 1
fi

SERVER_DOMAINS="$(ssh "${TARGET_HOST}" "grep '^QBITTORRENT_SERVER_DOMAINS=' '${REMOTE_ENV_FILE}' | cut -d= -f2-")"
HOST_HEADER_VALIDATION="$(ssh "${TARGET_HOST}" "grep '^QBITTORRENT_HOST_HEADER_VALIDATION=' '${REMOTE_ENV_FILE}' | cut -d= -f2-")"
REVERSE_PROXY_SUPPORT="$(ssh "${TARGET_HOST}" "grep '^QBITTORRENT_REVERSE_PROXY_SUPPORT=' '${REMOTE_ENV_FILE}' | cut -d= -f2-")"
TRUSTED_REVERSE_PROXIES="$(ssh "${TARGET_HOST}" "grep '^QBITTORRENT_TRUSTED_REVERSE_PROXIES=' '${REMOTE_ENV_FILE}' | cut -d= -f2-")"
WEBUI_PORT="$(ssh "${TARGET_HOST}" "grep '^QBITTORRENT_WEBUI_PORT=' '${REMOTE_ENV_FILE}' | cut -d= -f2-")"
HOST_BIND="$(ssh "${TARGET_HOST}" "grep '^QBITTORRENT_HOST_BIND=' '${REMOTE_ENV_FILE}' | cut -d= -f2-")"

DIRECT_WEBUI_HOST="${HOST_BIND:-127.0.0.1}"
if [[ "${DIRECT_WEBUI_HOST}" == "0.0.0.0" ]]; then
	DIRECT_WEBUI_HOST="127.0.0.1"
fi

PUBLIC_WEBUI_HOST="$(
	printf '%s' "${SERVER_DOMAINS}" |
		tr ';' '\n' |
		awk '
			$0 == "" { next }
			$0 == "localhost" { next }
			$0 == "127.0.0.1" { next }
			$0 ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/ { next }
			{ print; exit }
		'
)"

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

ssh "${TARGET_HOST}" "cd '${TARGET_DIR}' && ${DOCKER_PREFIX}${DOCKER_BIN} compose pull && ${DOCKER_PREFIX}${DOCKER_BIN} compose up -d && ${DOCKER_PREFIX}${DOCKER_BIN} stop nas-host-qbittorrent >/dev/null"

ssh "${TARGET_HOST}" \
	"${DOCKER_PREFIX}${DOCKER_BIN} run --rm -i --entrypoint python3 \
-v qbittorrent_qbittorrent_config:/config \
lscr.io/linuxserver/qbittorrent:latest - <<'PY'
from pathlib import Path
import base64
import hashlib
import os

password = '${WEBUI_PASSWORD}'
username = '${WEBUI_USERNAME}'
server_domains = '${SERVER_DOMAINS}'
host_header_validation = '${HOST_HEADER_VALIDATION:-true}'.lower()
reverse_proxy_support = '${REVERSE_PROXY_SUPPORT:-true}'.lower()
trusted_reverse_proxies = '${TRUSTED_REVERSE_PROXIES:-127.0.0.1;::1}'

p = Path('/config/qBittorrent/qBittorrent.conf')
lines = p.read_text().splitlines()
salt = os.urandom(16)
digest = hashlib.pbkdf2_hmac('sha512', password.encode(), salt, 100000)
password_hash = f'@ByteArray({base64.b64encode(salt).decode()}:{base64.b64encode(digest).decode()})'
sep = chr(92)
updates = {
    f'WebUI{sep}Username': username,
    f'WebUI{sep}Password_PBKDF2': password_hash,
    f'WebUI{sep}ServerDomains': server_domains,
    f'WebUI{sep}HostHeaderValidation': host_header_validation,
    f'WebUI{sep}ReverseProxySupportEnabled': reverse_proxy_support,
    f'WebUI{sep}TrustedReverseProxiesList': trusted_reverse_proxies,
}
out = []
seen = set()

for line in lines:
    replaced = False
    for key, value in updates.items():
        if line.startswith(key + '='):
            out.append(f'{key}={value}')
            seen.add(key)
            replaced = True
            break
    if not replaced:
        out.append(line)

for key, value in updates.items():
    if key not in seen:
        out.append(f'{key}={value}')

p.write_text('\\n'.join(out) + '\\n')
PY
${DOCKER_PREFIX}${DOCKER_BIN} start nas-host-qbittorrent >/dev/null"

echo "[deploy] qbittorrent deployed. Verify with:"
echo "         ssh ${TARGET_HOST} \"cd '${TARGET_DIR}' && ${DOCKER_PREFIX}${DOCKER_BIN} compose ps\""
echo "         ssh ${TARGET_HOST} \"cd '${TARGET_DIR}' && ${DOCKER_PREFIX}${DOCKER_BIN} compose logs --tail 80\""
echo "         ssh ${TARGET_HOST} \"curl -sS -m 6 -I http://${DIRECT_WEBUI_HOST}:${WEBUI_PORT} | sed -n '1,12p'\""
if [[ -n "${PUBLIC_WEBUI_HOST}" ]]; then
	echo "         curl -skI https://${PUBLIC_WEBUI_HOST}/ | sed -n '1,12p'"
fi
