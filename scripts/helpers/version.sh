#!/bin/bash

get_app_version() {
    local scheme="$1"

	xcrun xcodebuild \
		-scheme "${scheme}" \
		-showBuildSettings 2>/dev/null \
		| grep MARKETING_VERSION \
		| awk '{print $3;}'
}

bump_version() {
	local original_version="$1"
	awk -F. '{ $NF++; print; }' OFS=. <<< "${original_version}"
}
