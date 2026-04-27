#!/bin/sh
set -eu

target_host="${1:-hhnas4}"
repo_root="$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)"
dockerd_json_path="/var/packages/ContainerManager/etc/dockerd.json"

remote_docker_info() {
	ssh "${target_host}" sudo -n /usr/local/bin/docker info
}

remote_cat_dockerd() {
	# shellcheck disable=SC2029
	ssh "${target_host}" sudo cat "${dockerd_json_path}"
}

echo "[verify-docker-dns] target=${target_host}"

dockerd_json="$(remote_cat_dockerd)"
printf '%s\n' "${dockerd_json}"

printf '%s\n' "${dockerd_json}" | grep -q '"bip"' || {
	echo "[verify-docker-dns] missing bip in ${dockerd_json_path}" >&2
	exit 1
}

printf '%s\n' "${dockerd_json}" | grep -q '"default-address-pools"' || {
	echo "[verify-docker-dns] missing default-address-pools in ${dockerd_json_path}" >&2
	exit 1
}

printf '%s\n' "${dockerd_json}" | grep -q '"dns"' || {
	echo "[verify-docker-dns] missing dns in ${dockerd_json_path}" >&2
	exit 1
}

if rg -n '^[[:space:]]*dns:' "${repo_root}/hhnas4" --glob 'compose.yaml'; then
	echo "[verify-docker-dns] unexpected stack-local dns override found in hhnas4 compose files" >&2
	exit 1
fi

if rg -n '^WOODPECKER_BACKEND_DOCKER_DNS=' "${repo_root}/hhnas4/woodpecker-agent/.env.example"; then
	echo "[verify-docker-dns] woodpecker example keeps the DNS knob available for rollback"
fi

echo "[verify-docker-dns] docker info summary"
remote_docker_info | sed -n '1,160p' | grep -E 'Server Version|Storage Driver|Docker Root Dir|Default Address Pools| DNS:'

echo "[verify-docker-dns] docker networks"
ssh "${target_host}" 'sudo -n /usr/local/bin/docker network ls --format "{{.Name}}" | while read n; do sudo -n /usr/local/bin/docker network inspect "$n" --format "{{.Name}} {{range .IPAM.Config}}{{.Subnet}} {{end}}"; done | sort'

echo "[verify-docker-dns] OK"
