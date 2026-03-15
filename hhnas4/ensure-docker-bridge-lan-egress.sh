#!/bin/sh
set -eu

# Keep Docker bridge subnets able to reach LAN services on Synology hosts where
# FORWARD_FIREWALL applies a default drop policy.
#
# Rules ensured:
#   iptables -I FORWARD_FIREWALL <pos> -s <docker-subnet> -j RETURN
#   iptables -I INPUT_FIREWALL   <pos> -s <docker-subnet> -j RETURN
#
# This script is idempotent and intended to be run on boot (and optionally
# periodically) via user cron.

DOCKER_BIN="/usr/local/bin/docker"
TARGET="RETURN"
INSERT_POS="5"
IMAGE="alpine:3.20"

if [ ! -x "${DOCKER_BIN}" ]; then
	echo "[egress-fix] docker binary not found at ${DOCKER_BIN}" >&2
	exit 1
fi

run_iptables() {
	sudo -n "${DOCKER_BIN}" run --rm --privileged --network host -v /:/host "${IMAGE}" \
		chroot /host /usr/bin/iptables "$@"
}

docker_subnets() {
	sudo -n "${DOCKER_BIN}" network ls -q |
		xargs -r sudo -n "${DOCKER_BIN}" network inspect \
			--format '{{range .IPAM.Config}}{{if .Subnet}}{{println .Subnet}}{{end}}{{end}}' |
		sort -u
}

ensure_rule() {
	chain="$1"
	src_cidr="$2"
	if run_iptables -C "${chain}" -s "${src_cidr}" -j "${TARGET}" >/dev/null 2>&1; then
		echo "[egress-fix] rule already present: ${chain} ${src_cidr} -> ${TARGET}"
		return 0
	fi
	run_iptables -I "${chain}" "${INSERT_POS}" -s "${src_cidr}" -j "${TARGET}"
	echo "[egress-fix] inserted rule: ${chain} ${src_cidr} -> ${TARGET}"
}

docker_subnets | while IFS= read -r subnet; do
	[ -n "${subnet}" ] || continue
	ensure_rule "FORWARD_FIREWALL" "${subnet}"
	ensure_rule "INPUT_FIREWALL" "${subnet}"
done
