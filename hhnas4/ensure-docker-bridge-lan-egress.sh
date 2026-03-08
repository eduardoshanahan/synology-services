#!/usr/bin/env bash
set -euo pipefail

# Keep Docker bridge subnets able to reach LAN services on Synology hosts where
# FORWARD_FIREWALL applies a default drop policy.
#
# Rules ensured:
#   iptables -I FORWARD_FIREWALL <pos> -s 172.16.0.0/12 -j RETURN
#   iptables -I INPUT_FIREWALL   <pos> -s 172.16.0.0/12 -j RETURN
#
# This script is idempotent and intended to be run on boot (and optionally
# periodically) via user cron.

DOCKER_BIN="/usr/local/bin/docker"
SRC_CIDR="172.16.0.0/12"
TARGET="RETURN"
INSERT_POS="5"
IMAGE="alpine:3.20"

if [[ ! -x "${DOCKER_BIN}" ]]; then
	echo "[egress-fix] docker binary not found at ${DOCKER_BIN}" >&2
	exit 1
fi

run_iptables() {
	sudo -n "${DOCKER_BIN}" run --rm --privileged --network host -v /:/host "${IMAGE}" \
		chroot /host /usr/bin/iptables "$@"
}

ensure_rule() {
	local chain="$1"
	if run_iptables -C "${chain}" -s "${SRC_CIDR}" -j "${TARGET}" >/dev/null 2>&1; then
		echo "[egress-fix] rule already present: ${chain} ${SRC_CIDR} -> ${TARGET}"
		return 0
	fi
	run_iptables -I "${chain}" "${INSERT_POS}" -s "${SRC_CIDR}" -j "${TARGET}"
	echo "[egress-fix] inserted rule: ${chain} ${SRC_CIDR} -> ${TARGET}"
}

ensure_rule "FORWARD_FIREWALL"
ensure_rule "INPUT_FIREWALL"
