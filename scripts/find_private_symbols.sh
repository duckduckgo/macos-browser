#!/bin/bash

if ! [[ $common_sh ]]; then
	cwd="$(dirname "${BASH_SOURCE[0]}")"
	source "${cwd}/helpers/common.sh"
fi

print_usage_and_exit() {
	local reason=$1

	cat <<- EOF
	Usage:
	  $ $(basename "$0") <path_to_binary>

	Example:
	  $ $(basename "$0") release/DuckDuckGo.app/Contents/MacOS/DuckDuckGo

	EOF

	die "${reason}"
}

read_command_line_arguments() {
	if [[ "$1" == "-f" ]]; then
		force=1
		shift 1
	fi

	if (( $# < 1 )); then
		print_usage_and_exit "Binary not specified"
	fi

	if ! [[ -f "$1" ]]; then
		print_usage_and_exit "Binary is not a file"
	fi

	app_binary="$1"
	shift 1

	if ! [[ ${force} ]] && [[ "$1" == "-f" ]]; then
		force=1
	fi
}

check_binary_architectures() {
	local available_archs
	available_archs=$(lipo -archs "${app_binary}")

	number_of_archs=$(wc -w <<< "${available_archs}" | tr -d '[:space:]')

	if [[ ${number_of_archs} != 2 ]]; then
		die "Binary is compiled for a single architecture only (${available_archs}) - recompile with \`ONLY_ACTIVE_ARCH=NO\` or use \`-f\` to force."
	fi
}

find_private_objc_selectors() {
	# 1. List pointers to Obj-C selectors and their names.
	# 2. Filter out name.
	# 3. Remove __swift_objectForKeyedSubscript.
	# 4. Print only selectors starting with and underscore.
	otool -v -s __DATA __objc_selrefs "${app_binary}" \
		| sed -n -e 's/^.*__TEXT:__objc_methname://' \
            -e '/^__swift_objectForKeyedSubscript/d' \
			-e '/^__swift_setObject:forKeyedSubscript:/d' \
			-e '/^_/P' \
		| sort | uniq
}

main() {
	read_command_line_arguments "$@"

	if ! [[ ${force} ]]; then
		check_binary_architectures
	fi

	local selectors
	selectors=$(find_private_objc_selectors)

	if [[ -z "${selectors}" ]]; then
		echo "✅ No private API symbols found in the binary."
	else
		echo "🚨 Private API symbols found in the binary:"
		awk '{print "  * " $1; }' <<< "${selectors}"
	fi
}

main "$@"
