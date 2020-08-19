#!/usr/bin/env bash

# This script is supposed to run a playbook.
# It doesn't matter where you call it from.
# `playbooks/` will automatically be prepended to the path, while `.yml` will be appended.
# This results in `$0 <ansible_args> <playbook_name_without_yml>

# Fail on errors and unset variables
set -e
set -o nounset

# Try to run in nix-shell
if hash nix-shell &>/dev/null; then
	if [ -z "${IN_STUVUS_NIX_SHELL:-}" ]; then
		args="${0}"
		for param in "${@}"; do
			args="${args} \"${param}\""
		done
		exec nix-shell --arg inPlaybook true --run "${args}"
	fi
fi

if [ "${#}" -lt 1 ]; then
	echo "Usage: ${0} <ansible_args> <playbook_name_without_yml>"
	exit 1
fi

# Get the path of the playbook to execute
playbook="${!#}"
# Remove the last parameter
set -- "${@:1:$(($#-1))}"

# Prepare playbook execution
cd "$(dirname "$(readlink -f "${0}")")/.." || exit 255

# Check if playbook exists
if [ "${playbook}" != all ] && [ ! -f "${PWD}/playbooks/${playbook}.yml" ]; then
	echo "${PWD}/${playbook} does not exist"
	exit 1
fi

# Build environment
declare -a environment
parseEnvironmentFile() {
	while IFS= read -r line; do
		# Skip empty lines
		[ -z "${line}" ] && continue
		# Skip comments
		[[ "${line}" =~ ^[[:space:]]*#.*$ ]] && continue
		# See if we need to take the variable from the parent environment
		if [ "$(echo "${line}" | cut -d'=' -f2-)" = '' ]; then
			# This gets the name of the variable
			name="$(echo "${line}" | cut -d '=' -f1 | xargs)"
			# Ignore missing variables and assign
			[ -z "${!name:-}" ] || environment+=("${name}=${!name:-}")
		else
			# Append to environment array
			environment+=("${line}")
		fi
	done < "${1}"
}

# Try both the normal and local environment
parseEnvironmentFile environment
[ -f environment.local ] && parseEnvironmentFile environment.local

if [ "${playbook}" = all ]; then
	scripts/mkplaybook.py
else
	# Create a temporary playbook copy at the ansible root directory.
	# This workaround is needed to allow template or macro includes from tasks
	cp "playbooks/${playbook}.yml" ./.playbook.yml
fi
trap 'rm ./.playbook.yml' INT TERM EXIT

# Go!
exec env - "${environment[@]}" "${ANSIBLE_PLAYBOOK:-ansible-playbook}" "${@}" "./.playbook.yml"
