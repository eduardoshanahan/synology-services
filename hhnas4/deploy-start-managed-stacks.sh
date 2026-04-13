#!/usr/bin/env bash
# shellcheck disable=SC2029
set -euo pipefail

usage() {
	cat <<'USAGE'
Usage:
  deploy-start-managed-stacks.sh [target-host] [target-base] [--run-now]

Examples:
  ./deploy-start-managed-stacks.sh hhnas4
  ./deploy-start-managed-stacks.sh hhnas4 /volume1/docker/homelab/hhnas4 --run-now
USAGE
}

TARGET_HOST="hhnas4"
TARGET_BASE="/volume1/docker/homelab/hhnas4"
RUN_NOW=false

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
	--run-now)
		RUN_NOW=true
		shift
		;;
	*)
		echo "[deploy-start-stacks] unknown argument: $1" >&2
		usage >&2
		exit 2
		;;
	esac
done

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_SCRIPT="${SRC_DIR}/start-managed-stacks.sh"
REMOTE_SCRIPT="${TARGET_BASE}/start-managed-stacks.sh"

echo "[deploy-start-stacks] target host   : ${TARGET_HOST}"
echo "[deploy-start-stacks] target base   : ${TARGET_BASE}"
echo "[deploy-start-stacks] remote script : ${REMOTE_SCRIPT}"

ssh "${TARGET_HOST}" "mkdir -p '${TARGET_BASE}'"
cat "${LOCAL_SCRIPT}" | ssh "${TARGET_HOST}" "cat > '${REMOTE_SCRIPT}' && chmod +x '${REMOTE_SCRIPT}'"

echo "[deploy-start-stacks] deployed helper script"

if [[ "${RUN_NOW}" == "true" ]]; then
	echo "[deploy-start-stacks] running helper script now"
	ssh "${TARGET_HOST}" "'${REMOTE_SCRIPT}' '${TARGET_BASE}'"
fi

cat <<EOF
[deploy-start-stacks] DSM boot-task command:
  /bin/sh '${REMOTE_SCRIPT}' '${TARGET_BASE}' >> '${TARGET_BASE}/start-managed-stacks.log' 2>&1
EOF
