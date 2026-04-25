#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat <<'USAGE'
Usage:
  deploy.sh [target-host] [target-dir] [--update-env]

Examples:
  ./deploy.sh hhnas4
  ./deploy.sh hhnas4 /volume1/docker/homelab/hhnas4/mongo
  ./deploy.sh hhnas4 --update-env
USAGE
}

TARGET_HOST="hhnas4.internal.example"
TARGET_DIR="/volume1/docker/homelab/hhnas4/mongo"
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

read -r -d '' ENSURE_EXPORTER_ROLE_JS <<'EOF' || true
var admin = db.getSiblingDB("admin");
if (!admin.getRole("mongodb_exporter_system_version_read")) {
	admin.createRole({
		role: "mongodb_exporter_system_version_read",
		privileges: [
			{
				resource: { db: "admin", collection: "system.version" },
				actions: ["find"]
			}
		],
		roles: []
	});
}
admin.grantRolesToUser("mongo-metrics", [
	{ role: "mongodb_exporter_system_version_read", db: "admin" }
]);
print("ENSURED mongodb_exporter_system_version_read for mongo-metrics");
EOF

printf '%s\n' "${ENSURE_EXPORTER_ROLE_JS}" | ssh "${TARGET_HOST}" "cd '${TARGET_DIR}' && ${DOCKER_PREFIX}${DOCKER_BIN} compose exec -T mongo sh -lc '
set -e

cat > /tmp/mongodb-exporter-role.js

for attempt in \$(seq 1 30); do
	if mongo --quiet --host 127.0.0.1 --port 27017 \
		--username \"\$MONGO_INITDB_ROOT_USERNAME\" \
		--password \"\$MONGO_INITDB_ROOT_PASSWORD\" \
		--authenticationDatabase admin \
		--eval \"db.adminCommand({ ping: 1 }).ok\" | grep -q 1; then
		break
	fi
	sleep 2
done

mongo --quiet --host 127.0.0.1 --port 27017 \
	--username \"\$MONGO_INITDB_ROOT_USERNAME\" \
	--password \"\$MONGO_INITDB_ROOT_PASSWORD\" \
	--authenticationDatabase admin \
	/tmp/mongodb-exporter-role.js
'"

echo "[deploy] mongo deployed. Verify with:"
echo "         ssh ${TARGET_HOST} \"cd '${TARGET_DIR}' && ${DOCKER_PREFIX}${DOCKER_BIN} compose ps\""
echo "         ssh ${TARGET_HOST} \"cd '${TARGET_DIR}' && ${DOCKER_PREFIX}${DOCKER_BIN} compose logs --tail 60\""
echo "         ssh ${TARGET_HOST} \"cd '${TARGET_DIR}' && grep -E '^MONGO_(PORT|BIND)=' .env\""
