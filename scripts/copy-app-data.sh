#!/bin/bash

set -eo pipefail

cwd="$(dirname "${BASH_SOURCE[0]}")"
source "${cwd}/helpers/common.sh"
source "${cwd}/helpers/keychain.sh"

print_usage_and_exit() {
	local reason=$1

	cat <<- EOF
	Usage:

	To copy app data between two build types:
		$ $(basename "$0") [-f <build_type>] [-t <build_type>]

	To delete app data for a given build type:
		$ $(basename "$0") [-d <build_type>]

	Options:
	 -f <debug|review|release>  Specify source app - defaults to release
	 -t <debug|review>          Specify target app - defaults to debug
	 -d <debug|review>          Specify the app to delete data for - defaults to debug
	 -h                         Print this message

	EOF

	die "${reason}"
}

read_command_line_arguments() {
	while getopts 'hf:t:d:' OPTION; do
		case "${OPTION}" in
			h)
				print_usage_and_exit
				;;
			f)
				source="${OPTARG}"
				;;
			t)
				target="${OPTARG}"
				;;
			d)
				is_delete_mode=1
				source=""
				target="${OPTARG}"
				;;
			*)
				print_usage_and_exit "Unknown option '${OPTION}'"
				;;
		esac
	done

	shift $((OPTIND-1))
}

validate_source_and_target() {
	supported_sources=("debug" "review" "release")
	supported_targets=("debug" "review")

	# shellcheck disable=SC2076
	if [[ ! "${supported_targets[*]}" =~ "${target}" ]]; then
		print_usage_and_exit "Unknown target '${target}'"
	fi

	if ! [[ ${is_delete_mode} ]]; then

		# shellcheck disable=SC2076
		if [[ ! "${supported_sources[*]}" =~ "${source}" ]]; then
			print_usage_and_exit "Unknown source '${source}'"
		fi

		if [[ "${source}" == "${target}" ]]; then
			print_usage_and_exit 'Source and target apps cannot be the same'
		fi
	fi
}

get_bundle_id() {
	local build_type="$1"
	local prefix="com.duckduckgo.macos.browser"
	if [[ "${build_type}" != "release" ]]; then
		echo "${prefix}.${build_type}"
	else
		echo "${prefix}"
	fi
}

#
# Data Container
#

container_path() {
	local bundle_id="$1"
	echo "${HOME}/Library/Containers/${bundle_id}"
}

delete_container() {
	local container_path="$1"
	rm -rf "${container_path}"
}

copy_container() {
	local source_container="$1"
	local target_container="$2"

	if [[ -d "${source_container}" ]]; then
		cp -Rf "${source_container}" "${target_container}"
	fi
}

#
# Keychain
#

keychain_label="DuckDuckGo WebCrypto Master Key"

keychain_account() {
	local bundle_id="$1"
	echo "com.apple.WebKit.WebCrypto.master+${bundle_id}"
}

delete_keychain_entries() {
	local account="$1"

	if is_item_in_keychain "${account}" "${keychain_label}"; then
		delete_item_from_keychain "${account}" "${keychain_label}"
	fi
}

copy_keychain_entries() {
	local source_account="$1"
	local target_account="$2"
	local keychain_label="DuckDuckGo WebCrypto Master Key"

	if is_item_in_keychain "${source_account}" "${keychain_label}"; then
		local password
		password="$(retrieve_item_from_keychain "${source_account}" "${keychain_label}")"
		store_item_in_keychain "${target_account}" "${password}" "${keychain_label}"
	fi
}

#
# User Defaults
#

delete_defaults() {
	local bundle_id="$1"
	defaults delete "${bundle_id}"
}

copy_defaults() {
	local source_bundle_id="$1"
	local target_bundle_id="$2"
	defaults export "${source_bundle_id}" - | defaults import "${target_bundle_id}" -
}

#
# Main
#

main() {
	local source="release"
	local target="debug"
	local is_delete_mode

	read_command_line_arguments "$@"
	validate_source_and_target

	local target_bundle_id
	local target_container_path
	local target_keychain_account
	target_bundle_id="$(get_bundle_id "${target}")"
	target_container_path="$(container_path "${target_bundle_id}")"
	target_keychain_account="$(keychain_account "${target_bundle_id}")"

	if [[ ${is_delete_mode} ]]; then
		echo "Deleting ${target} app data ..."

		echo "* data container"
		delete_container "${target_container_path}"

		echo "* keychain entries"
		delete_keychain_entries "${target_keychain_account}"

		echo "* defaults"
		delete_defaults "${target_bundle_id}"

	else

		local source_bundle_id
		local source_container_path
		local source_keychain_account
		source_bundle_id="$(get_bundle_id "${source}")"
		source_container_path="$(container_path "${source_bundle_id}")"
		source_keychain_account="$(keychain_account "${source_bundle_id}")"

		echo "Copying ${source} app data to ${target} app ..."

		echo "* data container"
		delete_container "${target_container_path}"
		copy_container "${source_container_path}" "${target_container_path}"

		echo "* keychain entries"
		delete_keychain_entries "${target_keychain_account}"
		copy_keychain_entries "${source_keychain_account}" "${target_keychain_account}"

		echo "* defaults"
		delete_defaults "${target_bundle_id}"
		copy_defaults "${source_bundle_id}" "${target_bundle_id}"
	fi


	echo "Done"
}

main "$@"
