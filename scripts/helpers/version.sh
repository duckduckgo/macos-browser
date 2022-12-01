#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

_get_marketing_version() {
    local scheme="$1"

	xcrun xcodebuild \
		-scheme "${scheme}" \
		-showBuildSettings 2>/dev/null \
		| grep MARKETING_VERSION \
		| awk '{print $3;}'
}

get_app_version() {
    local scheme="$1"
	local version

	if ! version="$(_get_marketing_version "${scheme}")"; then
		read -r -d '' reason <<- EOF
		Failed to retrieve app version from Xcode project settings.
		Make sure that the following command works:
		    xcrun xcodebuild -scheme "${scheme}" -showBuildSettings

		EOF
		die "${reason}"
	fi

	echo "${version}"
}

bump_version() {
	local original_version="$1"
	awk -F. '{ $NF++; print; }' OFS=. <<< "${original_version}"
}
