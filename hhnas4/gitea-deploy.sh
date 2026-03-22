#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat <<'USAGE'
Usage:
  gitea-deploy.sh [target-host] [target-base] [--update-env] [--admin-user USER --admin-email EMAIL --admin-password PASSWORD]

Examples:
  ./gitea-deploy.sh hhnas4
  ./gitea-deploy.sh hhnas4 /volume1/docker/homelab/hhnas4
  ./gitea-deploy.sh hhnas4 --update-env
  ./gitea-deploy.sh hhnas4 --admin-user gitea-admin --admin-email admin@example.com --admin-password 'change-me'
USAGE
}

TARGET_HOST="hhnas4.internal.example"
TARGET_BASE="/volume1/docker/homelab/hhnas4"
UPDATE_ENV=0
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
	--update-env)
		UPDATE_ENV=1
		shift
		;;
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
# shellcheck disable=SC1091
source "${SRC_DIR}/../lib/env-source.sh"
REMOTE_GITEA_DIR="${TARGET_BASE}/gitea"
REMOTE_COMPOSE_FILE="${REMOTE_GITEA_DIR}/compose.yaml"
REMOTE_ENV_FILE="${REMOTE_GITEA_DIR}/.env"
REMOTE_CERTS_DIR="${REMOTE_GITEA_DIR}/certs"
LOCAL_ENV_FILE="${SRC_DIR}/gitea/.env"
LOCAL_SOPS_ENV_FILE="${SRC_DIR}/gitea/.env.sops"
synology_select_sops_env_file "${LOCAL_SOPS_ENV_FILE}"

echo "[deploy] target host: ${TARGET_HOST}"
echo "[deploy] target dir : ${REMOTE_GITEA_DIR}"

ssh "${TARGET_HOST}" "mkdir -p '${REMOTE_GITEA_DIR}' '${REMOTE_GITEA_DIR}/data' '${REMOTE_CERTS_DIR}'"

# Always stream-copy compose (works even when scp subsystem is disabled).
cat "${SRC_DIR}/gitea/compose.yaml" | ssh "${TARGET_HOST}" "cat > '${REMOTE_COMPOSE_FILE}'"

if [[ -n "${SYN_SELECTED_SOPS_ENV_FILE}" ]]; then
	SOPS_BIN="$(command -v sops || true)"
	if [[ -z "${SOPS_BIN}" ]]; then
		echo "[deploy] ${SYN_SELECTED_SOPS_ENV_FILE} exists but sops is not installed." >&2
		echo "[deploy] enter 'nix develop' in synology-services (or install sops) and retry." >&2
		exit 1
	fi
fi

# Seed .env once; preserve existing host-local values on subsequent deploys.
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
		cat "${SRC_DIR}/gitea/.env.example" | ssh "${TARGET_HOST}" "cat > '${REMOTE_ENV_FILE}'"
		echo "[deploy] created ${REMOTE_ENV_FILE} from template"
	fi
else
	echo "[deploy] keeping existing ${REMOTE_ENV_FILE}"
fi

# Keep the homelab root CA in sync so outbound TLS from the container trusts
# internal services (for example Authentik OIDC discovery).
cat "${SRC_DIR}/gitea/certs/homelab-root-ca.crt" | ssh "${TARGET_HOST}" "cat > '${REMOTE_CERTS_DIR}/homelab-root-ca.crt'"

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

# Declarative OIDC source sync (optional).
# Reads Authentik OIDC values from remote .env and ensures a matching OAuth2
# login source exists in Gitea.
ssh "${TARGET_HOST}" "bash -s -- '${REMOTE_GITEA_DIR}' '${DOCKER_BIN}' '${REMOTE_ENV_FILE}'" <<'EOF'
set -euo pipefail

REMOTE_GITEA_DIR="$1"
DOCKER_BIN="$2"
REMOTE_ENV_FILE="$3"

if [[ ! -f "$REMOTE_ENV_FILE" ]]; then
	echo "[deploy] OIDC sync skipped: missing $REMOTE_ENV_FILE"
	exit 0
fi

read_env() {
	local key="$1"
	awk -F= -v k="$key" '$1 == k { sub(/^[^=]*=/, "", $0); print; exit }' "$REMOTE_ENV_FILE"
}

bool_is_true() {
	local v
	v="$(printf '%s' "${1:-}" | tr -d '\r' | tr '[:upper:]' '[:lower:]')"
	[[ "$v" == "1" || "$v" == "true" || "$v" == "yes" || "$v" == "on" ]]
}

if "$DOCKER_BIN" info >/dev/null 2>&1; then
	DOCKER_PREFIX=()
elif sudo -n "$DOCKER_BIN" info >/dev/null 2>&1; then
	DOCKER_PREFIX=(sudo -n)
else
	DOCKER_PREFIX=(sudo)
fi

docker_compose() {
	cd "$REMOTE_GITEA_DIR"
	"${DOCKER_PREFIX[@]}" "$DOCKER_BIN" compose "$@"
}

OIDC_ENABLED="$(read_env GITEA_AUTHENTIK_OIDC_ENABLED)"
OIDC_NAME="$(read_env GITEA_AUTHENTIK_OIDC_NAME)"
OIDC_DISCOVERY_URL="$(read_env GITEA_AUTHENTIK_OIDC_DISCOVERY_URL)"
OIDC_CLIENT_ID="$(read_env GITEA_AUTHENTIK_OIDC_CLIENT_ID)"
OIDC_CLIENT_SECRET="$(read_env GITEA_AUTHENTIK_OIDC_CLIENT_SECRET)"
OIDC_SCOPES="$(read_env GITEA_AUTHENTIK_OIDC_SCOPES)"
OIDC_GROUP_CLAIM_NAME="$(read_env GITEA_AUTHENTIK_OIDC_GROUP_CLAIM_NAME)"
OIDC_ADMIN_GROUP="$(read_env GITEA_AUTHENTIK_OIDC_ADMIN_GROUP)"
OIDC_RESTRICTED_GROUP="$(read_env GITEA_AUTHENTIK_OIDC_RESTRICTED_GROUP)"
OIDC_SKIP_LOCAL_2FA="$(read_env GITEA_AUTHENTIK_OIDC_SKIP_LOCAL_2FA)"

OIDC_NAME="${OIDC_NAME:-authentik}"
OIDC_DISCOVERY_URL="${OIDC_DISCOVERY_URL:-https://authentik.internal.example/application/o/gitea/.well-known/openid-configuration}"
OIDC_SCOPES="${OIDC_SCOPES:-openid profile email}"
OIDC_SKIP_LOCAL_2FA="${OIDC_SKIP_LOCAL_2FA:-false}"

if ! bool_is_true "$OIDC_ENABLED"; then
	echo "[deploy] OIDC sync skipped: GITEA_AUTHENTIK_OIDC_ENABLED is not true"
	exit 0
fi

if [[ -z "$OIDC_CLIENT_ID" || -z "$OIDC_CLIENT_SECRET" || -z "$OIDC_DISCOVERY_URL" ]]; then
	echo "[deploy] OIDC sync skipped: set GITEA_AUTHENTIK_OIDC_CLIENT_ID, GITEA_AUTHENTIK_OIDC_CLIENT_SECRET, and GITEA_AUTHENTIK_OIDC_DISCOVERY_URL in .env" >&2
	exit 0
fi

oauth_args=(
	--name "$OIDC_NAME"
	--provider openidConnect
	--key "$OIDC_CLIENT_ID"
	--secret "$OIDC_CLIENT_SECRET"
	--auto-discover-url "$OIDC_DISCOVERY_URL"
)

for scope in $OIDC_SCOPES; do
	oauth_args+=(--scopes "$scope")
done

if [[ -n "$OIDC_GROUP_CLAIM_NAME" ]]; then
	oauth_args+=(--group-claim-name "$OIDC_GROUP_CLAIM_NAME")
fi

if [[ -n "$OIDC_ADMIN_GROUP" ]]; then
	oauth_args+=(--admin-group "$OIDC_ADMIN_GROUP")
fi

if [[ -n "$OIDC_RESTRICTED_GROUP" ]]; then
	oauth_args+=(--restricted-group "$OIDC_RESTRICTED_GROUP")
fi

if bool_is_true "$OIDC_SKIP_LOCAL_2FA"; then
	oauth_args+=(--skip-local-2fa)
fi

existing_id="$(
	docker_compose exec -T --user git gitea /usr/local/bin/gitea admin auth list \
	| awk -v n="$OIDC_NAME" '$2 == n && $3 == "OAuth2" { print $1; exit }'
)"

if [[ -n "$existing_id" ]]; then
	docker_compose exec -T --user git gitea /usr/local/bin/gitea admin auth update-oauth \
		--id "$existing_id" \
		"${oauth_args[@]}" >/dev/null
	echo "[deploy] updated OIDC auth source in Gitea: ${OIDC_NAME} (id=${existing_id})"
else
	docker_compose exec -T --user git gitea /usr/local/bin/gitea admin auth add-oauth \
		"${oauth_args[@]}" >/dev/null
	echo "[deploy] created OIDC auth source in Gitea: ${OIDC_NAME}"
fi
EOF

echo "[deploy] gitea deployed. Verify with:"
echo "         ssh ${TARGET_HOST} \"cd '${REMOTE_GITEA_DIR}' && ${DOCKER_PREFIX}${DOCKER_BIN} compose ps\""
echo "         ssh ${TARGET_HOST} \"curl -sSI http://127.0.0.1:3000/ | head -n 1\""
