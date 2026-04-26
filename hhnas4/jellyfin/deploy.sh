#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat <<'USAGE'
Usage:
  ./deploy.sh [target-host] [target-dir] [--update-env]

Examples:
  ./deploy.sh hhnas4.internal.example
  ./deploy.sh hhnas4.internal.example /volume1/docker/homelab/hhnas4/jellyfin
  ./deploy.sh hhnas4.internal.example --update-env
USAGE
}

TARGET_HOST="hhnas4.internal.example"
TARGET_DIR="/volume1/docker/homelab/hhnas4/jellyfin"
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

ssh "${TARGET_HOST}" "mkdir -p '${TARGET_DIR}' '${TARGET_DIR}/config' '${TARGET_DIR}/cache'"

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

MEDIA_DIR="$(ssh "${TARGET_HOST}" "grep '^JELLYFIN_MEDIA_DIR=' '${REMOTE_ENV_FILE}' | cut -d= -f2-")"
if [[ -z "${MEDIA_DIR}" ]]; then
	echo "[deploy] JELLYFIN_MEDIA_DIR is missing in ${REMOTE_ENV_FILE}" >&2
	exit 1
fi

if ! ssh "${TARGET_HOST}" "test -d '${MEDIA_DIR}'"; then
	echo "[deploy] Jellyfin media directory does not exist on target: ${MEDIA_DIR}" >&2
	echo "[deploy] update ${REMOTE_ENV_FILE} and retry." >&2
	exit 1
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

HARDENED_COUNT="$(
	ssh "${TARGET_HOST}" "
set -euo pipefail
LIB_ROOT='${TARGET_DIR}/config/root/default'
TIMESTAMP=\$(date +%Y%m%d%H%M%S)
HARDENED=0

if [ -d \"\${LIB_ROOT}\" ]; then
	for OPTIONS_FILE in \"\${LIB_ROOT}\"/*/options.xml; do
		[ -f \"\${OPTIONS_FILE}\" ] || continue
		TMP_FILE=\$(mktemp)
		sed \
			-e 's#<EnableRealtimeMonitor>true</EnableRealtimeMonitor>#<EnableRealtimeMonitor>false</EnableRealtimeMonitor>#g' \
			-e 's#<EnableLUFSScan>true</EnableLUFSScan>#<EnableLUFSScan>false</EnableLUFSScan>#g' \
			-e 's#<AutomaticRefreshIntervalDays>[0-9][0-9]*</AutomaticRefreshIntervalDays>#<AutomaticRefreshIntervalDays>0</AutomaticRefreshIntervalDays>#g' \
			\"\${OPTIONS_FILE}\" >\"\${TMP_FILE}\"

		if ! cmp -s \"\${OPTIONS_FILE}\" \"\${TMP_FILE}\"; then
			cp \"\${OPTIONS_FILE}\" \"\${OPTIONS_FILE}.bak-\${TIMESTAMP}\"
			cat \"\${TMP_FILE}\" >\"\${OPTIONS_FILE}\"
			HARDENED=\$((HARDENED + 1))
		fi
		rm -f \"\${TMP_FILE}\"
	done
fi

printf '%s' \"\${HARDENED}\"
"
)"

if [[ "${HARDENED_COUNT}" =~ ^[0-9]+$ ]] && ((HARDENED_COUNT > 0)); then
	echo "[deploy] hardened ${HARDENED_COUNT} Jellyfin library option file(s) (realtime monitor/LUFS disabled)."
	echo "[deploy] restarting hhnas4-jellyfin to apply updated library options."
	ssh "${TARGET_HOST}" "${DOCKER_PREFIX}${DOCKER_BIN} restart hhnas4-jellyfin >/dev/null"
fi

echo "[deploy] jellyfin deployed. Verify with:"
echo "         ssh ${TARGET_HOST} \"cd '${TARGET_DIR}' && ${DOCKER_PREFIX}${DOCKER_BIN} compose ps\""
echo "         ssh ${TARGET_HOST} \"cd '${TARGET_DIR}' && ${DOCKER_PREFIX}${DOCKER_BIN} compose logs --tail 120\""
echo "         ssh ${TARGET_HOST} \"curl -sS -m 6 -i http://127.0.0.1:\$(grep '^JELLYFIN_PORT=' '${REMOTE_ENV_FILE}' | cut -d= -f2) | sed -n '1,12p'\""
