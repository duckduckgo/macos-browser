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
	local length="${1:-8}"
	uuidgen | tr -d '-' | tr '[:upper:]' '[:lower:]' | cut -c "1-${length}"
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
# This allows to modify (or delete) original script(s) during execution
# (e.g. as a result of branch switching).
# It sets `cwd` variable to point to temporary directory.
#
execute_from_tmp() {
	local source_script_path="${PWD}/$1"

	if ! [[ ${tempdir} ]]; then
		trap 'rm -rf "$tempdir"' EXIT

		tempdir="$(mktemp -d)"
		source_script_name="$(basename "${source_script_path}")"
		source_script_dir="$(dirname "${source_script_path}")"
		source_script_dir_name="$(basename "${source_script_dir}")"

		export cwd="${tempdir}/${source_script_dir_name}"
		temp_script_path="${cwd}/${source_script_name}"

		cp -R "${source_script_dir}" "${tempdir}"

		shift 1
		# shellcheck source=/dev/null
		source "${temp_script_path}" "$@"
		exit
	fi
}
