#!/bin/bash

export common_sh=1

#
# Output passed arguments to stderr and exit.
#
die() {
	cat >&2 <<< "$*"
	exit 1
}

random_string() {
	uuidgen | tr -d '-' | tr '[:upper:]' '[:lower:]'
}

silent_output() {
	"$@" >/dev/null 2>&1
}

#
# Runs script from a temporary directory:
# 1. creates a temporary directory
# 2. copies `scripts` directory over there
# 3. runs the script passed as first parameter, passing other parameters to it
#
# This allows to modify original script(s) during execution.
#
execute_from_tmp() {
	local source_script_path="${PWD}/$1"

	if ! [[ ${tempdir} ]]; then
		trap 'rm -rf "$tempdir"' EXIT

		tempdir="$(mktemp -d)"
		source_script_name="$(basename "${source_script_path}")"
		source_script_dir="$(dirname "${source_script_path}")"
		source_script_dir_name="$(basename "${source_script_dir}")"
		temp_script_path="${tempdir}/${source_script_dir_name}/${source_script_name}"

		cp -R "${source_script_dir}" "${tempdir}"

		shift 1
		# shellcheck source=/dev/null
		source "${temp_script_path}" "$@"
		exit
	fi
}
