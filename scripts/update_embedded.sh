#!/bin/bash

set -eo pipefail

temp_filename="embedded_new_file"
temp_etag_filename="embedded_new_etag"

rm -f "$temp_filename"
rm -f "$temp_etag_filename"

performUpdate() {
	local file_url=$1
	local provider_path=$2
	local data_path=$3
	printf "Processing: %s\n" "${file_url}"

	if test ! -f "$data_path"; then
		printf "Error: %s does not exist\n" "${data_path}"
		exit 1
	fi

	if test ! -f "$provider_path"; then
		printf "Error: %s does not exist\n" "${provider_path}"
		exit 1
	fi

	old_etag=$(grep 'public static let embeddedDataETag' "${provider_path}" | awk -F '\\\\"' '{print $2}')
	old_sha=$(grep 'public static let embeddedDataSHA' "${provider_path}" | awk -F '"' '{print $2}')

	printf "Existing ETag: %s\n" "${old_etag}"
	printf "Existing SHA256: %s\n" "${old_sha}"
 
	curl -s -o "$temp_filename" -H "If-None-Match: \"${old_etag}\"" --etag-save "$temp_etag_filename" "${file_url}"

	if test -f $temp_filename; then
		new_etag=$(< "$temp_etag_filename" awk -F '"' '{print $2}')
		new_sha=$(shasum -a 256 "$temp_filename" | awk -F ' ' '{print $1}')

		printf "New ETag: %s\n" "$new_etag"
		printf "New SHA256: %s\n" "$new_sha"

		sed -i '' "s/$old_etag/$new_etag/g" "${provider_path}"
		sed -i '' "s/$old_sha/$new_sha/g" "${provider_path}"

		cp -f "$temp_filename" "$data_path"

		printf 'Files updated\n\n'
	else
		printf 'Nothing to update\n\n'
	fi

	rm -f "$temp_filename"
	rm -f "$temp_etag_filename"
}

performUpdate 'https://staticcdn.duckduckgo.com/trackerblocking/v2.1/apple-tds.json' \
		"${PWD}/DuckDuckGo/Content Blocker/AppTrackerDataSetProvider.swift" \
		"${PWD}/DuckDuckGo/Content Blocker/trackerData.json"
performUpdate 'https://staticcdn.duckduckgo.com/trackerblocking/config/v2/macos-config.json' \
		"${PWD}/DuckDuckGo/Content Blocker/AppPrivacyConfigurationDataProvider.swift" \
		"${PWD}/DuckDuckGo/Content Blocker/macos-config.json"
