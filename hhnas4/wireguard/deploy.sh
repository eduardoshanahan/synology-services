#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat <<'USAGE'
Usage:
  deploy.sh [target-host] [target-dir] [--update-env]

Examples:
  ./deploy.sh hhnas4
  ./deploy.sh hhnas4 /volume1/docker/homelab/hhnas4/wireguard
  ./deploy.sh hhnas4 --update-env
USAGE
}

TARGET_HOST="hhnas4.internal.example"
TARGET_DIR="/volume1/docker/homelab/hhnas4/wireguard"
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
REMOTE_WG_CONF="${TARGET_DIR}/wg0.conf"
LOCAL_WG_CONF_TEMPLATE="${SRC_DIR}/wg0.conf.template"
LOCAL_SOPS_ENV_FILE="${SRC_DIR}/.env.sops"
synology_select_sops_env_file "${LOCAL_SOPS_ENV_FILE}"

echo "[deploy] target host: ${TARGET_HOST}"
echo "[deploy] target dir : ${TARGET_DIR}"

# Create remote directory
ssh "${TARGET_HOST}" "mkdir -p '${TARGET_DIR}'"

# Copy compose.yaml
cat "${SRC_DIR}/compose.yaml" | ssh "${TARGET_HOST}" "cat > '${REMOTE_COMPOSE_FILE}'"
echo "[deploy] copied compose.yaml"

# Generate and copy wg0.conf from template
if [[ -n "${SYN_SELECTED_SOPS_ENV_FILE}" ]]; then
	SOPS_BIN="$(command -v sops || true)"
	if [[ -z "${SOPS_BIN}" ]]; then
		echo "[deploy] ${SYN_SELECTED_SOPS_ENV_FILE} exists but sops is not installed." >&2
		echo "[deploy] enter 'nix develop' in synology-services (or install sops) and retry." >&2
		exit 1
	fi

	# Decrypt .env.sops and extract WG_PRIVATE_KEY
	WG_PRIVATE_KEY=$(sops -d --input-type dotenv --output-type dotenv "${SYN_SELECTED_SOPS_ENV_FILE}" | grep '^WG_PRIVATE_KEY=' | cut -d'=' -f2-)

	# Generate wg0.conf from template
	sed "s|\${WG_PRIVATE_KEY}|${WG_PRIVATE_KEY}|g" "${LOCAL_WG_CONF_TEMPLATE}" | ssh "${TARGET_HOST}" "cat > '${REMOTE_WG_CONF}'"
	echo "[deploy] generated and copied wg0.conf"
else
	echo "[deploy] ERROR: .env.sops not found. WireGuard requires private key." >&2
	exit 1
fi

# Find docker binary on Synology
DOCKER_BIN="$(ssh "${TARGET_HOST}" "command -v docker || { test -x /usr/local/bin/docker && echo /usr/local/bin/docker; } || { test -x /var/packages/ContainerManager/target/usr/bin/docker && echo /var/packages/ContainerManager/target/usr/bin/docker; } || { test -x /var/packages/Docker/target/usr/bin/docker && echo /var/packages/Docker/target/usr/bin/docker; }")"

if [[ -z "${DOCKER_BIN}" ]]; then
	echo "[deploy] could not find docker binary on ${TARGET_HOST}" >&2
	exit 1
fi

# Determine if sudo is needed
if ssh "${TARGET_HOST}" "${DOCKER_BIN} info >/dev/null 2>&1"; then
	DOCKER_PREFIX=""
elif ssh "${TARGET_HOST}" "sudo -n ${DOCKER_BIN} info >/dev/null 2>&1"; then
	DOCKER_PREFIX="sudo -n "
else
	DOCKER_PREFIX="sudo "
fi

# Deploy container
ssh "${TARGET_HOST}" "cd '${TARGET_DIR}' && ${DOCKER_PREFIX}${DOCKER_BIN} compose down 2>/dev/null || true && ${DOCKER_PREFIX}${DOCKER_BIN} compose up -d"

echo "[deploy] WireGuard deployed successfully"
echo "[deploy] Check status: ssh ${TARGET_HOST} '${DOCKER_PREFIX}${DOCKER_BIN} exec hhnas4-wireguard wg show'"
