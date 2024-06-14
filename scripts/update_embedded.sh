#!/bin/bash

set -eo pipefail

# The following URLs shall match the ones in AppConfigurationURLprovider.swift.
# Danger checks that the URLs match on every PR. If the code changes, the regex that Danger uses may need an update.
TDS_URL="https://staticcdn.duckduckgo.com/trackerblocking/v6/current/macos-tds.json"
CONFIG_URL="https://staticcdn.duckduckgo.com/trackerblocking/config/v4/macos-config.json"

# If -c is passed, then check the URLs in the Configuration files are correct.
if [ "$1" == "-c" ]; then
	grep http DuckDuckGo/Application/AppConfigurationURLProvider.swift | while read -r line
	do
		# if trimmed line begins with "case" then check the url in the line and ensure
		# it matches the expected url.
		if [[ $line =~ ^\s*case ]]; then
			# Get URL from line and remove quotes
			url=$(echo "$line" | awk '{print $4}' | sed 's/^"//' | sed 's/"$//')
			case_name=$(echo "$line" | awk '{print $2}')
			if [ "$case_name" == "trackerDataSet" ] && [ "$url" != "$TDS_URL" ]; then
				echo "Error: $url does not match $TDS_URL"
				exit 1
			elif [ "$case_name" == "privacyConfiguration" ] && [ "$url" != "$CONFIG_URL" ]; then
				echo "Error: $url does not match $CONFIG_URL"
				exit 1
			fi
		fi
	done

	exit 0
fi

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

performUpdate $TDS_URL \
		"${PWD}/DuckDuckGo/ContentBlocker/AppTrackerDataSetProvider.swift" \
		"${PWD}/DuckDuckGo/ContentBlocker/trackerData.json"
performUpdate $CONFIG_URL \
		"${PWD}/DuckDuckGo/ContentBlocker/AppPrivacyConfigurationDataProvider.swift" \
		"${PWD}/DuckDuckGo/ContentBlocker/macos-config.json"
