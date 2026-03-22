#!/usr/bin/env bash

synology_find_public_repo_root() {
	local dir="$1"

	while [[ "$dir" != "/" ]]; do
		if [[ -f "${dir}/flake.nix" && -f "${dir}/AGENTS.md" && -f "${dir}/README.md" ]]; then
			printf '%s\n' "$dir"
			return 0
		fi
		dir="$(dirname "$dir")"
	done

	return 1
}

synology_select_sops_env_file() {
	local local_sops_env_file="$1"
	local start_dir public_repo_root private_repo_root relative_sops_path

	# shellcheck disable=SC2034
	SYN_LOCAL_SOPS_ENV_FILE="${local_sops_env_file}"
	# shellcheck disable=SC2034
	SYN_PRIVATE_SOPS_ENV_FILE=""
	# shellcheck disable=SC2034
	SYN_SELECTED_SOPS_ENV_FILE=""

	start_dir="$(dirname "${local_sops_env_file}")"
	public_repo_root="$(synology_find_public_repo_root "${start_dir}" || true)"
	if [[ -z "${public_repo_root}" ]]; then
		if [[ -f "${local_sops_env_file}" ]]; then
			# shellcheck disable=SC2034
			SYN_SELECTED_SOPS_ENV_FILE="${local_sops_env_file}"
		fi
		return 0
	fi

	private_repo_root="${SYNOLOGY_SERVICES_PRIVATE_ROOT:-$(dirname "${public_repo_root}")/synology-services-private}"
	if [[ "${local_sops_env_file}" == "${public_repo_root}/"* ]]; then
		relative_sops_path="${local_sops_env_file#"${public_repo_root}"/}"
		SYN_PRIVATE_SOPS_ENV_FILE="${private_repo_root}/${relative_sops_path}"
	fi

	if [[ -n "${SYN_PRIVATE_SOPS_ENV_FILE}" && -f "${SYN_PRIVATE_SOPS_ENV_FILE}" ]]; then
		# shellcheck disable=SC2034
		SYN_SELECTED_SOPS_ENV_FILE="${SYN_PRIVATE_SOPS_ENV_FILE}"
	elif [[ -f "${local_sops_env_file}" ]]; then
		# shellcheck disable=SC2034
		SYN_SELECTED_SOPS_ENV_FILE="${local_sops_env_file}"
	fi
}
