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

TARGET="RETURN"
INSERT_POS="5"
IMAGE="alpine:3.20"
DOCKER_BIN=""
DOCKER_PREFIX=""

resolve_docker() {
	for candidate in \
		"$(command -v docker 2>/dev/null || true)" \
		"/usr/local/bin/docker" \
		"/var/packages/ContainerManager/target/usr/bin/docker" \
		"/var/packages/Docker/target/usr/bin/docker"; do
		[ -n "${candidate}" ] || continue
		[ -x "${candidate}" ] || continue
		DOCKER_BIN="${candidate}"
		break
	done

	if [ -z "${DOCKER_BIN}" ]; then
		echo "[egress-fix] docker binary not found" >&2
		exit 1
	fi

	if "${DOCKER_BIN}" info >/dev/null 2>&1; then
		DOCKER_PREFIX=""
		return 0
	fi

	if sudo -n "${DOCKER_BIN}" info >/dev/null 2>&1; then
		DOCKER_PREFIX="sudo -n"
		return 0
	fi

	echo "[egress-fix] docker daemon is not ready or requires interactive sudo" >&2
	exit 1
}

docker_cmd() {
	if [ -n "${DOCKER_PREFIX}" ]; then
		${DOCKER_PREFIX} "${DOCKER_BIN}" "$@"
	else
		"${DOCKER_BIN}" "$@"
	fi
}

run_iptables() {
	docker_cmd run --rm --privileged --network host -v /:/host "${IMAGE}" \
		chroot /host /usr/bin/iptables "$@"
}

docker_subnets() {
	docker_cmd network ls -q |
		while IFS= read -r network_id; do
			[ -n "${network_id}" ] || continue
			docker_cmd network inspect \
				--format '{{range .IPAM.Config}}{{if .Subnet}}{{println .Subnet}}{{end}}{{end}}' \
				"${network_id}"
		done |
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

resolve_docker

docker_subnets | while IFS= read -r subnet; do
	[ -n "${subnet}" ] || continue
	ensure_rule "FORWARD_FIREWALL" "${subnet}"
	ensure_rule "INPUT_FIREWALL" "${subnet}"
done
