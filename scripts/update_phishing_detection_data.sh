#!/bin/bash
#set -eo pipefail
#
## The following URLs shall match the one in the client.
## Danger checks that the URLs match on every PR. If the code changes, the regex that Danger uses may need an update.
API_URL="https://hugely-divine-toucan.ngrok-free.app"
API_STAGING_URL="https://tbd.unknown.duckduckgo.com"

temp_filename="phishing_data_new_file"
new_revision=$(curl -s "${API_URL}/revision" | jq -r '.revision')

rm -f "$temp_filename"

# If pr-body is the only argument, then we produce the PR body for this update
if [ "$1" == "pr-body" ]; then
	echo "# Phishing Detection Data Updates"
	echo "Embedded data has been updated to revision {{revision}}"
	echo "# Steps to test this PR:"
	echo "1. Check there is data in hashPrefixes.json and filterSet.json"
	echo "2. Check the revision in PhishingDetectionManagerFactory.swift is updated to $new_revision"
	echo "3. Check the SHA256 of the data in hashPrefixes.json and filterSet.json is updated"
	exit 0
fi

# if "revision" is the only argument, then we just return the current server revision
if [ "$1" == "revision" ]; then
	echo $new_revision
	exit 0
fi

performUpdate() {
	local data_type=$1
	local provider_path=$2
	local data_path=$3
	printf "Processing: %s\n" "${data_type}"

	if test ! -f "$data_path"; then
		printf "Error: %s does not exist\n" "${data_path}"
		exit 1
	fi

	if test ! -f "$provider_path"; then
		printf "Error: %s does not exist\n" "${provider_path}"
		exit 1
	fi

	old_sha=$(grep 'private static let '${data_type}'DataSHA' "${provider_path}" | awk -F '"' '{print $2}')
	old_revision=$(grep 'public static let revision' "${provider_path}" | awk -F '=' '{print $2}' | tr -d ' ')

	printf "Existing SHA256: %s\n" "${old_sha}"
	printf "Existing revision: %s\n" "${old_revision}"
	printf "New revision: %s\n" "${new_revision}"

	if [ $old_revision -lt $new_revision ]; then
        curl -o $temp_filename -s "${API_URL}/${data_type}"
		cat "$temp_filename" | jq -r '.insert' > "$data_path"

		new_sha=$(shasum -a 256 "$data_path" | awk -F ' ' '{print $1}')

		printf "New SHA256: %s\n" "$new_sha"

        sed -i '' -e "s/$old_sha/$new_sha/g" "${provider_path}"

		printf 'Files updated\n\n'
	else
		printf 'Nothing to update\n\n'
	fi

	rm -f "$temp_filename"
}

updateRevision() {
    local new_revision=$1
	local provider_path=$2
	old_revision=$(grep 'public static let revision' "${provider_path}" | awk -F '=' '{print $2}' | tr -d ' ')

	if [ $old_revision -lt $new_revision ]; then
		sed -i '' -e "s/public static let revision =.*/public static let revision = $new_revision/" "${provider_path}"
        printf "Updated revision from $old_revision to $new_revision\n"
	fi
}

performUpdate hashPrefix \
		"${PWD}/DuckDuckGo/PhishingDetection/PhishingDetectionManagerFactory.swift" \
		"${PWD}/DuckDuckGo/PhishingDetection/hashPrefixes.json"

performUpdate filterSet \
		"${PWD}/DuckDuckGo/PhishingDetection/PhishingDetectionManagerFactory.swift" \
		"${PWD}/DuckDuckGo/PhishingDetection/filterSet.json"

updateRevision $new_revision "${PWD}/DuckDuckGo/PhishingDetection/PhishingDetectionManagerFactory.swift" 
