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
    echo "❌ Could not read embeddedDataRevision"
    exit 1
fi

temp_filename="phishing_data_new_file"
new_revision=$(curl --compressed -s "${API_URL}/revision" | jq -r '.revision')

printf "Embedded revision: %s, actual revision: %s\n\n" "${old_revision}" "${new_revision}"
rm -f "$temp_filename"

performUpdate() {
    local threat_type=$1
	local data_type=$2
	local data_path=$3
    capitalized_data_type="$(echo "${data_type}" | awk '{print toupper(substr($0, 1, 1)) substr($0, 2)}')"
	printf "Processing %s\n" "${threat_type}${capitalized_data_type}"

	old_sha="$(grep "static let ${threat_type}Embedded${capitalized_data_type}DataSHA =" "${def_filename}" | awk -F '"' '{print $2}')"
    if [ -z "$old_sha" ]; then
        echo "⚠️ Could not read ${threat_type}Embedded${capitalized_data_type}DataSHA"
        old_sha=""
    fi

	printf "Embedded SHA256: %s\n" "${old_sha}"

    url="${API_URL}/${data_type}?category=${threat_type}"
    printf "Fetching %s\n" "${url}"
    curl --compressed -o "$temp_filename" -H "Cache-Control: no-cache" -s "${url}"
    # Extract the revision from the fetched JSON
    revision=$(jq -r '.revision' "$temp_filename")

    # Compare the fetched revision with the local new_revision variable
    if [ "$revision" != "$new_revision" ]; then
        echo "❌ Revision mismatch! Expected '$new_revision', got '$revision' – ${temp_filename}"
        exit 1
    fi
    printf "writing to %s\n" "${data_path}"
    jq -rc '.insert' "$temp_filename" > "$data_path"

    new_sha="$(shasum -a 256 "$data_path" | awk -F ' ' '{print $1}')"

    if [ "$new_sha" != "$old_sha" ]; then
        printf "New SHA256: %s ✨\n" "$new_sha"
    fi

    sed -i '' -e "s/${threat_type}Embedded${capitalized_data_type}DataSHA =.*/${threat_type}Embedded${capitalized_data_type}DataSHA = \"$new_sha\"/g" "${def_filename}"
    sed -i '' -e "s/${threat_type}EmbeddedDataRevision =.*/${threat_type}EmbeddedDataRevision = $new_revision/" "${def_filename}"

    # Validate number of records in the data file
    record_count=$(jq 'length' "$data_path")
    if [ "$record_count" -eq 0 ]; then
        echo "⚠️⚠️⚠️: No data at $data_path"
    elif [ "$new_sha" == "$old_sha" ]; then
        printf "🆗 Data not modified. Number of records: %d\n\n" "$record_count"
    else
        printf "✅ %s updated with %d records\n\n" "${threat_type}Embedded${capitalized_data_type}DataSHA" "$record_count"
    fi

	rm -f "$temp_filename"
}

updateRevision() {
    sed -i '' -e "s/embeddedDataRevision = $old_revision/embeddedDataRevision = $new_revision/" "${def_filename}"
    printf "Updated revision from %s to %s\n" "$old_revision" "$new_revision"
}

if [[ "$old_revision" -lt "$new_revision" ]] || [[ "$*" == *"-f"* ]]; then
    performUpdate phishing hashPrefix "${work_dir}/phishingHashPrefixes.json"
    performUpdate phishing filterSet "${work_dir}/phishingFilterSet.json"

    performUpdate malware hashPrefix "${work_dir}/malwareHashPrefixes.json"
    performUpdate malware filterSet "${work_dir}/malwareFilterSet.json"

    updateRevision
else
    printf 'Nothing to update\n\n'
fi
