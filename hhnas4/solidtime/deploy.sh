#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat <<'USAGE'
Usage:
  deploy.sh [target-host] [target-dir] [--update-env]

Examples:
  ./deploy.sh nas-host
  ./deploy.sh nas-host /volume1/docker/homelab/nas-host/solidtime
  ./deploy.sh nas-host --update-env
USAGE
}

TARGET_HOST="nas-host.internal.example"
TARGET_DIR="/volume1/docker/homelab/nas-host/solidtime"
SHARED_DB_NETWORK="${SHARED_DB_NETWORK:-hhlab-shared-db}"
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
REMOTE_LARAVEL_ENV_FILE="${TARGET_DIR}/laravel.env"
LOCAL_ENV_FILE="${SRC_DIR}/.env"
LOCAL_LARAVEL_ENV_FILE="${SRC_DIR}/laravel.env"
LOCAL_SOPS_ENV_FILE="${SRC_DIR}/.env.sops"
LOCAL_SOPS_LARAVEL_ENV_FILE="${SRC_DIR}/laravel.env.sops"

echo "[deploy] target host: ${TARGET_HOST}"
echo "[deploy] target dir : ${TARGET_DIR}"

ssh "${TARGET_HOST}" "mkdir -p '${TARGET_DIR}' '${TARGET_DIR}/logs' '${TARGET_DIR}/app-storage'"

cat "${SRC_DIR}/compose.yaml" | ssh "${TARGET_HOST}" "cat > '${REMOTE_COMPOSE_FILE}'"

if [[ -f "${LOCAL_SOPS_ENV_FILE}" || -f "${LOCAL_SOPS_LARAVEL_ENV_FILE}" ]]; then
	SOPS_BIN="$(command -v sops || true)"
	if [[ -z "${SOPS_BIN}" ]]; then
		echo "[deploy] encrypted env file detected but sops is not installed." >&2
		echo "[deploy] enter 'nix develop' in synology-services (or install sops) and retry." >&2
		exit 1
	fi
fi

sync_env_file() {
	local remote_file="$1"
	local local_sops_file="$2"
	local local_plain_file="$3"
	local template_file="$4"

	if ((UPDATE_ENV)); then
		if [[ -f "${local_sops_file}" ]]; then
			sops -d --input-type dotenv --output-type dotenv "${local_sops_file}" |
				ssh "${TARGET_HOST}" "cat > '${remote_file}'"
			echo "[deploy] updated ${remote_file} from $(basename "${local_sops_file}")"
		elif [[ -f "${local_plain_file}" ]]; then
			cat "${local_plain_file}" | ssh "${TARGET_HOST}" "cat > '${remote_file}'"
			echo "[deploy] updated ${remote_file} from $(basename "${local_plain_file}")"
		else
			echo "[deploy] --update-env was set but no source file exists for ${remote_file}." >&2
			exit 1
		fi
	elif ssh "${TARGET_HOST}" "test ! -f '${remote_file}'"; then
		if [[ -f "${local_sops_file}" ]]; then
			sops -d --input-type dotenv --output-type dotenv "${local_sops_file}" |
				ssh "${TARGET_HOST}" "cat > '${remote_file}'"
			echo "[deploy] created ${remote_file} from $(basename "${local_sops_file}")"
		elif [[ -f "${local_plain_file}" ]]; then
			cat "${local_plain_file}" | ssh "${TARGET_HOST}" "cat > '${remote_file}'"
			echo "[deploy] created ${remote_file} from $(basename "${local_plain_file}")"
		else
			cat "${template_file}" | ssh "${TARGET_HOST}" "cat > '${remote_file}'"
			echo "[deploy] created ${remote_file} from template"
		fi
	else
		echo "[deploy] keeping existing ${remote_file}"
	fi
}

sync_env_file "${REMOTE_ENV_FILE}" "${LOCAL_SOPS_ENV_FILE}" "${LOCAL_ENV_FILE}" "${SRC_DIR}/.env.example"
sync_env_file "${REMOTE_LARAVEL_ENV_FILE}" "${LOCAL_SOPS_LARAVEL_ENV_FILE}" "${LOCAL_LARAVEL_ENV_FILE}" "${SRC_DIR}/laravel.env.example"

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

ssh "${TARGET_HOST}" "${DOCKER_PREFIX}${DOCKER_BIN} network inspect '${SHARED_DB_NETWORK}' >/dev/null 2>&1 || ${DOCKER_PREFIX}${DOCKER_BIN} network create '${SHARED_DB_NETWORK}'"

# Solidtime image runs as uid/gid 1000; ensure bind-mounted paths are writable.
ssh "${TARGET_HOST}" "${DOCKER_PREFIX}${DOCKER_BIN} run --rm -v '${TARGET_DIR}/logs:/target' busybox sh -lc 'mkdir -p /target && chown -R 1000:1000 /target && chmod -R u+rwX,g+rwX,o-rwx /target'"
ssh "${TARGET_HOST}" "${DOCKER_PREFIX}${DOCKER_BIN} run --rm -v '${TARGET_DIR}/app-storage:/target' busybox sh -lc 'mkdir -p /target && chown -R 1000:1000 /target && chmod -R u+rwX,g+rwX,o-rwx /target'"

ssh "${TARGET_HOST}" "cd '${TARGET_DIR}' && ${DOCKER_PREFIX}${DOCKER_BIN} compose pull && ${DOCKER_PREFIX}${DOCKER_BIN} compose up -d --remove-orphans"

echo "[deploy] solidtime deployed. Next steps:"
echo "         1) Generate keys once:"
echo "            ssh ${TARGET_HOST} \"cd '${TARGET_DIR}' && ${DOCKER_PREFIX}${DOCKER_BIN} compose run --rm scheduler php artisan self-host:generate-keys\""
echo "         2) Put APP_KEY, PASSPORT_PRIVATE_KEY, PASSPORT_PUBLIC_KEY into ${REMOTE_LARAVEL_ENV_FILE}"
echo "         3) Restart after env update:"
echo "            ssh ${TARGET_HOST} \"cd '${TARGET_DIR}' && ${DOCKER_PREFIX}${DOCKER_BIN} compose up -d\""
echo "         4) Run DB migrations:"
echo "            ssh ${TARGET_HOST} \"cd '${TARGET_DIR}' && ${DOCKER_PREFIX}${DOCKER_BIN} compose exec scheduler php artisan migrate --force\""
echo "         5) Create first admin user:"
echo "            ssh ${TARGET_HOST} \"cd '${TARGET_DIR}' && ${DOCKER_PREFIX}${DOCKER_BIN} compose exec scheduler php artisan admin:user:create 'Your Name' 'you@example.com' --verify-email\""
echo "         6) Verify status:"
echo "            ssh ${TARGET_HOST} \"cd '${TARGET_DIR}' && ${DOCKER_PREFIX}${DOCKER_BIN} compose ps\""
echo "            ssh ${TARGET_HOST} \"curl -sSI http://127.0.0.1:\${APP_PORT:-3800}/ | head -n 5\""
