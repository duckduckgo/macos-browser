#!/bin/bash
#set -eo pipefail
#
## The following URLs shall match the one in the client.
## Danger checks that the URLs match on every PR. If the code changes, the regex that Danger uses may need an update.
API_URL="https://duckduckgo.com/api/protection"

work_dir="${PWD}/DuckDuckGo/MaliciousSiteProtection"
def_filename="${work_dir}/MaliciousSiteProtectionManager.swift"

old_revision="$(grep "static let embeddedDataRevision =" "${def_filename}" | awk -F '[=,]' '{print $2}' | xargs)"
if [ -z "$old_revision" ]; then
    echo "Error: Could not read embeddedDataRevision"
    exit 1
fi

temp_filename="phishing_data_new_file"
new_revision=$(curl -s "${API_URL}/revision" | jq -r '.revision')

printf "Embedded revision: %s, actual revision: %s\n" "${old_revision}" "${new_revision}"
rm -f "$temp_filename"

performUpdate() {
    local threat_type=$1
	local data_type=$2
	local data_path=$3
    capitalized_data_type="$(echo "${data_type}" | awk '{print toupper(substr($0, 1, 1)) substr($0, 2)}')"
	printf "Processing %s\n" "${threat_type}${capitalized_data_type}"

	old_sha="$(grep "static let ${threat_type}Embedded${capitalized_data_type}DataSHA =" "${def_filename}" | awk -F '"' '{print $2}')"
    if [ -z "$old_sha" ]; then
        echo "Error: Could not read ${threat_type}Embedded${capitalized_data_type}DataSHA"
        exit 1
    fi

	printf "Embedded SHA256: %s\n" "${old_sha}"

    curl -o "$temp_filename" -s "${API_URL}/${data_type}"
    jq -rc '.insert' "$temp_filename" > "$data_path"

    new_sha="$(shasum -a 256 "$data_path" | awk -F ' ' '{print $1}')"

    printf "New SHA256: %s\n" "$new_sha"

    sed -i '' -e "s/$old_sha/$new_sha/g" "${def_filename}"
    sed -i '' -e "s/${threat_type}EmbeddedDataRevision =.*/${threat_type}EmbeddedDataRevision = $new_revision/" "${def_filename}"

    printf "${threat_type}Embedded${capitalized_data_type}DataSHA updated\n\n"
	rm -f "$temp_filename"
}

updateRevision() {
    sed -i '' -e "s/revision = $old_revision/revision = $new_revision/" "${def_filename}"
    printf "Updated revision from %s to %s\n" "$old_revision" "$new_revision"
}

if [ "$old_revision" -lt "$new_revision" ]; then
    performUpdate phishing hashPrefix "${work_dir}/phishingHashPrefixes.json"
    performUpdate phishing filterSet "${work_dir}/phishingFilterSet.json"

    performUpdate malware hashPrefix "${work_dir}/malwareHashPrefixes.json"
    performUpdate malware filterSet "${work_dir}/malwareFilterSet.json"

    updateRevision
else
    printf 'Nothing to update\n\n'
fi
