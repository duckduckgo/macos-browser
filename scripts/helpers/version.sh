#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

_extract_build_setting() {
    local scheme="$1"
	local variable_name="$2"

	xcrun xcodebuild \
		-scheme "${scheme}" \
		-showBuildSettings 2>/dev/null \
		| grep "${variable_name}" \
		| awk '{print $3;}'
}

get_app_version() {
    local scheme="$1"
	local version

	if ! version="$(_extract_build_setting "${scheme}" MARKETING_VERSION)"; then
		read -r -d '' reason <<- EOF
		Failed to retrieve app version from Xcode project settings.
		Make sure that the following command works:
		    xcrun xcodebuild -scheme "${scheme}" -showBuildSettings

		EOF
		die "${reason}"
	fi

	echo "${version}"
}

get_build_number() {
    local scheme="$1"
	local build_number

	if ! build_number="$(_extract_build_setting "${scheme}" CURRENT_PROJECT_VERSION)"; then
		read -r -d '' reason <<- EOF
		Failed to retrieve build number from Xcode project settings.
		Make sure that the following command works:
		    xcrun xcodebuild -scheme "${scheme}" -showBuildSettings

		EOF
		die "${reason}"
	fi

	echo "${build_number}"
}
