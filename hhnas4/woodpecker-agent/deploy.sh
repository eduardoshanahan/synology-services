#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat <<'USAGE'
Usage:
  deploy.sh [target-host] [target-dir]

Examples:
  ./deploy.sh hhnas4
  ./deploy.sh hhnas4 /volume1/docker/homelab/hhnas4/woodpecker-agent
USAGE
}

TARGET_HOST="hhnas4.internal.example"
TARGET_DIR="/volume1/docker/homelab/hhnas4/woodpecker-agent"

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
REMOTE_CERTS_DIR="${TARGET_DIR}/certs"
REMOTE_CA_BUNDLE_FILE="${REMOTE_CERTS_DIR}/ca-certificates-with-homelab.pem"

echo "[deploy] target host: ${TARGET_HOST}"
echo "[deploy] target dir : ${TARGET_DIR}"

ssh "${TARGET_HOST}" "mkdir -p '${TARGET_DIR}' '${REMOTE_CERTS_DIR}'"

cat "${SRC_DIR}/compose.yaml" | ssh "${TARGET_HOST}" "cat > '${REMOTE_COMPOSE_FILE}'"

if ssh "${TARGET_HOST}" "test ! -f '${REMOTE_ENV_FILE}'"; then
	cat "${SRC_DIR}/.env.example" | ssh "${TARGET_HOST}" "cat > '${REMOTE_ENV_FILE}'"
	echo "[deploy] created ${REMOTE_ENV_FILE} from template"
else
	echo "[deploy] keeping existing ${REMOTE_ENV_FILE}"
fi

if ssh "${TARGET_HOST}" "! grep -q '^WOODPECKER_CA_CERT_HOST_PATH=' '${REMOTE_ENV_FILE}'"; then
	ssh "${TARGET_HOST}" "printf '\nWOODPECKER_CA_CERT_HOST_PATH=%s\n' '${REMOTE_CERTS_DIR}/homelab-root-ca.crt' >> '${REMOTE_ENV_FILE}'"
	echo "[deploy] appended WOODPECKER_CA_CERT_HOST_PATH to ${REMOTE_ENV_FILE}"
fi

if ssh "${TARGET_HOST}" "! grep -q '^WOODPECKER_CA_BUNDLE_HOST_PATH=' '${REMOTE_ENV_FILE}'"; then
	ssh "${TARGET_HOST}" "printf 'WOODPECKER_CA_BUNDLE_HOST_PATH=%s\n' '${REMOTE_CA_BUNDLE_FILE}' >> '${REMOTE_ENV_FILE}'"
	echo "[deploy] appended WOODPECKER_CA_BUNDLE_HOST_PATH to ${REMOTE_ENV_FILE}"
fi

if ssh "${TARGET_HOST}" "grep -q '^WOODPECKER_BACKEND_DOCKER_VOLUMES=/etc/ssl/certs:/etc/ssl/certs:ro$' '${REMOTE_ENV_FILE}'"; then
	ssh "${TARGET_HOST}" "python3 - <<'PY'
from pathlib import Path
env_file = Path('${REMOTE_ENV_FILE}')
old = 'WOODPECKER_BACKEND_DOCKER_VOLUMES=/etc/ssl/certs:/etc/ssl/certs:ro'
new = 'WOODPECKER_BACKEND_DOCKER_VOLUMES=${REMOTE_CA_BUNDLE_FILE}:/etc/ssl/cert.pem:ro,${REMOTE_CERTS_DIR}/homelab-root-ca.crt:/etc/ssl/certs/homelab-root-ca.crt:ro'
env_file.write_text(env_file.read_text().replace(old, new))
PY"
	echo "[deploy] upgraded WOODPECKER_BACKEND_DOCKER_VOLUMES in ${REMOTE_ENV_FILE}"
fi

cat "${SRC_DIR}/../gitea/certs/homelab-root-ca.crt" | ssh "${TARGET_HOST}" "cat > '${REMOTE_CERTS_DIR}/homelab-root-ca.crt'"
ssh "${TARGET_HOST}" "cat /etc/ssl/certs/ca-certificates.crt '${REMOTE_CERTS_DIR}/homelab-root-ca.crt' > '${REMOTE_CA_BUNDLE_FILE}'"
cat "${SRC_DIR}/../gitea/certs/homelab-root-ca.crt" | ssh "${TARGET_HOST}" "cat > '/tmp/homelab-root-ca.crt'"

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

echo "[deploy] woodpecker agent deployed. Verify with:"
echo "         ssh ${TARGET_HOST} \"cd '${TARGET_DIR}' && ${DOCKER_PREFIX}${DOCKER_BIN} compose ps\""
echo "         ssh ${TARGET_HOST} \"cd '${TARGET_DIR}' && ${DOCKER_PREFIX}${DOCKER_BIN} compose logs --tail 40\""
