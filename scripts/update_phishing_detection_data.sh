#!/bin/bash
#set -eo pipefail
#
## The following URLs shall match the one in the client.
## Danger checks that the URLs match on every PR. If the code changes, the regex that Danger uses may need an update.
API_URL="http://localhost:3000"

temp_filename="phishing_data_new_file"
new_revision=$(curl -s "${API_URL}/revision" | jq -r '.revision')

rm -f "$temp_filename"

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
	old_sha="$(grep "${data_type}DataSHA: String =" "${provider_path}" | awk -F '"' '{print $2}')"

	old_revision=$(grep 'revision: Int' "${provider_path}" | awk -F '[=,]' '{print $2}' | xargs)

	printf "Existing SHA256: %s\n" "${old_sha}"
	printf "Existing revision: %s, new revision: %s\n" "${old_revision}" "${new_revision}"

	if [ "$old_revision" -lt "$new_revision" ]; then
        curl -o "$temp_filename" -s "${API_URL}/${data_type}"
		jq -r '.insert' "$temp_filename" > "$data_path"

		new_sha="$(shasum -a 256 "$data_path" | awk -F ' ' '{print $1}')"

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
	old_revision=$(grep 'revision: Int' "${provider_path}" | awk -F '[=,]' '{print $2}' | xargs)

	if [ "$old_revision" -lt "$new_revision" ]; then
		sed -i '' -e "s/revision: Int =.*/revision: Int = $new_revision,/" "${provider_path}"
		printf "Updated revision from %s to %s\n" "$old_revision" "$new_revision"
	fi
}

performUpdate hashPrefix \
		"${PWD}/DuckDuckGo/PhishingDetection/PhishingDetection.swift" \
		"${PWD}/DuckDuckGo/PhishingDetection/hashPrefixes.json"

performUpdate filterSet \
		"${PWD}/DuckDuckGo/PhishingDetection/PhishingDetection.swift" \
		"${PWD}/DuckDuckGo/PhishingDetection/filterSet.json"

updateRevision "$new_revision" "${PWD}/DuckDuckGo/PhishingDetection/PhishingDetection.swift" 
