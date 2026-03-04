#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat <<'USAGE'
Usage:
  deploy.sh [target-host] [target-base] [--admin-user USER --admin-email EMAIL --admin-password PASSWORD] [--without-promtail]

Examples:
  ./deploy.sh hhnas4
  ./deploy.sh hhnas4 /volume1/docker/homelab/hhnas4
  ./deploy.sh hhnas4 --admin-user gitea-admin --admin-email admin@example.com --admin-password 'change-me'
USAGE
}

TARGET_HOST="hhnas4.internal.example"
TARGET_BASE="/volume1/docker/homelab/hhnas4"
WITH_PROMTAIL="1"
ADMIN_USER=""
ADMIN_EMAIL=""
ADMIN_SECRET=""

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

while [[ $# -gt 0 ]]; do
	case "$1" in
	--admin-user)
		ADMIN_USER="${2:-}"
		shift 2
		;;
	--admin-email)
		ADMIN_EMAIL="${2:-}"
		shift 2
		;;
	--admin-password)
		ADMIN_SECRET="${2:-}"
		shift 2
		;;
	--without-promtail)
		WITH_PROMTAIL="0"
		shift
		;;
	*)
		echo "[deploy] unknown argument: $1" >&2
		usage >&2
		exit 2
		;;
	esac
done

if [[ -n "${ADMIN_USER}" || -n "${ADMIN_EMAIL}" || -n "${ADMIN_SECRET}" ]]; then
	if [[ -z "${ADMIN_USER}" || -z "${ADMIN_EMAIL}" || -z "${ADMIN_SECRET}" ]]; then
		echo "[deploy] when using admin bootstrap, set --admin-user, --admin-email, and --admin-password." >&2
		exit 2
	fi
fi

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REMOTE_GITEA_DIR="${TARGET_BASE}/gitea"
REMOTE_COMPOSE_FILE="${REMOTE_GITEA_DIR}/compose.yaml"
REMOTE_ENV_FILE="${REMOTE_GITEA_DIR}/.env"
REMOTE_PROMTAIL_DIR="${TARGET_BASE}/promtail"
REMOTE_PROMTAIL_COMPOSE_FILE="${REMOTE_PROMTAIL_DIR}/compose.yaml"
REMOTE_PROMTAIL_ENV_FILE="${REMOTE_PROMTAIL_DIR}/.env"
REMOTE_PROMTAIL_CONFIG_FILE="${REMOTE_PROMTAIL_DIR}/config.yml"

echo "[deploy] target host: ${TARGET_HOST}"
echo "[deploy] target dir : ${REMOTE_GITEA_DIR}"

ssh "${TARGET_HOST}" "mkdir -p '${REMOTE_GITEA_DIR}' '${REMOTE_GITEA_DIR}/data'"

# Always stream-copy compose (works even when scp subsystem is disabled).
cat "${SRC_DIR}/gitea/compose.yaml" | ssh "${TARGET_HOST}" "cat > '${REMOTE_COMPOSE_FILE}'"

# Seed .env once; preserve existing host-local values on subsequent deploys.
if ssh "${TARGET_HOST}" "test ! -f '${REMOTE_ENV_FILE}'"; then
	cat "${SRC_DIR}/gitea/.env.example" | ssh "${TARGET_HOST}" "cat > '${REMOTE_ENV_FILE}'"
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

ssh "${TARGET_HOST}" "cd '${REMOTE_GITEA_DIR}' && ${DOCKER_PREFIX}${DOCKER_BIN} compose pull && ${DOCKER_PREFIX}${DOCKER_BIN} compose up -d"

if [[ -n "${ADMIN_USER}" ]]; then
	ssh "${TARGET_HOST}" "cd '${REMOTE_GITEA_DIR}' && ${DOCKER_PREFIX}${DOCKER_BIN} compose exec -T --user git gitea /usr/local/bin/gitea admin user create --username '${ADMIN_USER}' --email '${ADMIN_EMAIL}' --password '${ADMIN_SECRET}' --admin --must-change-password=false >/dev/null 2>&1 || true"
	if ssh "${TARGET_HOST}" "cd '${REMOTE_GITEA_DIR}' && ${DOCKER_PREFIX}${DOCKER_BIN} compose exec -T --user git gitea /usr/local/bin/gitea admin user list | awk 'NR>1 {print \$2}' | grep -Fx '${ADMIN_USER}' >/dev/null"; then
		echo "[deploy] ensured admin user exists: ${ADMIN_USER}"
	else
		echo "[deploy] failed to verify admin user: ${ADMIN_USER}" >&2
		exit 1
	fi
fi

if [[ "${WITH_PROMTAIL}" == "1" ]]; then
	ssh "${TARGET_HOST}" "mkdir -p '${REMOTE_PROMTAIL_DIR}' '${REMOTE_PROMTAIL_DIR}/data'"
	cat "${SRC_DIR}/promtail/compose.yaml" | ssh "${TARGET_HOST}" "cat > '${REMOTE_PROMTAIL_COMPOSE_FILE}'"
	cat "${SRC_DIR}/promtail/config.yml" | ssh "${TARGET_HOST}" "cat > '${REMOTE_PROMTAIL_CONFIG_FILE}'"

	if ssh "${TARGET_HOST}" "test ! -f '${REMOTE_PROMTAIL_ENV_FILE}'"; then
		cat "${SRC_DIR}/promtail/.env.example" | ssh "${TARGET_HOST}" "cat > '${REMOTE_PROMTAIL_ENV_FILE}'"
		echo "[deploy] created ${REMOTE_PROMTAIL_ENV_FILE} from template"
	else
		echo "[deploy] keeping existing ${REMOTE_PROMTAIL_ENV_FILE}"
	fi

	ssh "${TARGET_HOST}" "cd '${REMOTE_PROMTAIL_DIR}' && ${DOCKER_PREFIX}${DOCKER_BIN} compose pull && ${DOCKER_PREFIX}${DOCKER_BIN} compose up -d"
fi

echo "[deploy] gitea deployed. Verify with:"
echo "         ssh ${TARGET_HOST} \"cd '${REMOTE_GITEA_DIR}' && ${DOCKER_PREFIX}${DOCKER_BIN} compose ps\""
echo "         ssh ${TARGET_HOST} \"curl -sSI http://127.0.0.1:3000/ | head -n 1\""
if [[ "${WITH_PROMTAIL}" == "1" ]]; then
	echo "[deploy] promtail deployed. Verify with:"
	echo "         ssh ${TARGET_HOST} \"cd '${REMOTE_PROMTAIL_DIR}' && ${DOCKER_PREFIX}${DOCKER_BIN} compose ps\""
	echo "         ssh ${TARGET_HOST} \"curl -sSI http://127.0.0.1:9080/ready | head -n 1\""
fi
