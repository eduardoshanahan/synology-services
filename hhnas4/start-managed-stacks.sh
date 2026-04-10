#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat <<'USAGE'
Usage:
  start-managed-stacks.sh [base-dir]

Examples:
  ./start-managed-stacks.sh
  ./start-managed-stacks.sh /volume1/docker/homelab/nas-host

Notes:
  - Intended to run directly on the Synology host.
  - Safe to re-run; each stack uses `docker compose up -d`.
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
	usage
	exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="${1:-$SCRIPT_DIR}"

if [[ $# -gt 1 ]]; then
	echo "[start-stacks] too many arguments" >&2
	usage >&2
	exit 2
fi

if command -v docker >/dev/null 2>&1; then
	DOCKER_BIN="docker"
elif [[ -x /usr/local/bin/docker ]]; then
	DOCKER_BIN="/usr/local/bin/docker"
elif [[ -x /var/packages/ContainerManager/target/usr/bin/docker ]]; then
	DOCKER_BIN="/var/packages/ContainerManager/target/usr/bin/docker"
elif [[ -x /var/packages/Docker/target/usr/bin/docker ]]; then
	DOCKER_BIN="/var/packages/Docker/target/usr/bin/docker"
else
	echo "[start-stacks] docker binary not found" >&2
	exit 1
fi

if "${DOCKER_BIN}" compose version >/dev/null 2>&1; then
	DOCKER_PREFIX=()
elif sudo -n "${DOCKER_BIN}" compose version >/dev/null 2>&1; then
	DOCKER_PREFIX=(sudo -n)
else
	DOCKER_PREFIX=(sudo)
fi

STACKS=(
	postgres
	redis
	mysql
	mongo
	dolt
	minio
	tika
	gotenberg
	gitea
	outline
	paperless
	karakeep
	freshrss
	immich
	qbittorrent
	jellyfin
	promtail
	docker-socket-proxy
	adminer
	archivebox
	woodpecker-agent
	wireguard
)

# Some host-level projects live outside the managed nas-host stack base.
# Keep these in the same recovery flow so monitoring survives host restarts.
EXTRA_COMPOSE_DIRS=(
	/volume1/docker/homelab/nas-observability
)

echo "[start-stacks] base dir    : ${BASE_DIR}"
echo "[start-stacks] docker bin  : ${DOCKER_BIN}"
echo "[start-stacks] docker mode : ${DOCKER_PREFIX[*]:-direct}"

failures=0
for stack in "${STACKS[@]}"; do
	stack_dir="${BASE_DIR}/${stack}"
	compose_file="${stack_dir}/compose.yaml"
	env_file="${stack_dir}/.env"

	if [[ ! -f "${compose_file}" ]]; then
		echo "[start-stacks] skip ${stack}: missing compose file"
		continue
	fi

	if [[ ! -f "${env_file}" ]]; then
		echo "[start-stacks] skip ${stack}: missing env file"
		continue
	fi

	echo "[start-stacks] up ${stack}"
	if ! "${DOCKER_PREFIX[@]}" "${DOCKER_BIN}" compose -f "${compose_file}" --env-file "${env_file}" up -d; then
		echo "[start-stacks] failed ${stack}" >&2
		failures=$((failures + 1))
	fi
done

for project_dir in "${EXTRA_COMPOSE_DIRS[@]}"; do
	compose_file="${project_dir}/compose.yaml"

	if [[ ! -f "${compose_file}" ]]; then
		echo "[start-stacks] skip extra ${project_dir}: missing compose file"
		continue
	fi

	echo "[start-stacks] up extra ${project_dir}"
	if ! "${DOCKER_PREFIX[@]}" "${DOCKER_BIN}" compose -f "${compose_file}" up -d; then
		echo "[start-stacks] failed extra ${project_dir}" >&2
		failures=$((failures + 1))
	fi
done

if [[ "${failures}" -gt 0 ]]; then
	echo "[start-stacks] completed with ${failures} stack failure(s)" >&2
	exit 1
fi

echo "[start-stacks] completed successfully"
