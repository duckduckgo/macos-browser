#!/bin/bash
#
# This scripts fetches Asana tasks from the Origins section defined in the Asana project https://app.asana.com/0/1206716555947156/1206716715679835.
# 

set -e -o pipefail

asana_api_url="https://app.asana.com/api/1.0"

# Create a JSON string with the `origin-variant` pairs from the list of .
_create_origins_and_variants() {
	local response="$1"
	local origin_field="Origin"
	local atb_field="ATB"

	# for each element in the data array.
	# filter out element with null `origin`.
	# select `origin` and `variant` from the custom_fields response and make a key:value pair structure like {origin: <origin_value>, variant: <variant_value>}.
	# if variant is not null we need to create two entries. One only with `origin` and one with `origin` and `variant` 
	# replace the new line with a comma
	# remove the trailing comma at the end of the line.
	jq -c '.data[]
		| select(.custom_fields[] | select(.name == "'"${origin_field}"'").text_value != null)
		| {origin: (.custom_fields[] | select(.name == "'"${origin_field}"'") | .text_value), variant: (.custom_fields[] | select(.name == "'"${atb_field}"'") | .text_value)}
		| if .variant != null then {origin}, {origin, variant} else {origin} end' <<< "$response"
}

# Fetch all the Asana tasks in the section specified by ORIGIN_ASANA_SECTION_ID for a project.
# This function fetches only uncompleted tasks.
# If there are more than 100 items the function takes care of pagination.
# Returns a JSON string consisting of a list of `origin-variant` pairs concatenated by a comma. Eg. `{"origin":"app","variant":"ab"},{"origin":"app.search","variant":null}`.  
_fetch_origin_tasks() {
	# Fetches only tasks that have not been completed yet, includes in the response section name, name of the task and its custom fields. 
	local query="completed_since=now&opt_fields=name,custom_fields.id_prefix,custom_fields.name,custom_fields.text_value&opt_expand=custom_fields&opt_fields=memberships.section.name&limit=100"

	local url="${asana_api_url}/sections/${ORIGIN_ASANA_SECTION_ID}/tasks?${query}"
	local response
	local origin_variants=()

	# go through all tasks in the section (there may be multiple requests in case there are more than 100 tasks in the section)
	# repeat until no more pages (next_page.uri is null)
	while true; do
		response="$(curl -fLSs "$url" -H "Authorization: Bearer ${ASANA_ACCESS_TOKEN}")"
		
		# extract the object in the data array and append to result
		origin_variants+=("$(_create_origins_and_variants "$response")")

		# set new URL to next page URL
		url="$(jq -r .next_page.uri <<< "$response")"

		# break on last page
		if [[ "$url" == "null" ]]; then
			break
		fi
	done

	printf "%s\n" "${origin_variants[@]}"
}

# Create a JSON string from the list of ATB items passed.
_create_atb_variant_pairs() {
	local response="$1"

	# read the response raw and format in a compact JSON mode
	# map each element to the structure {variant:<element>}
	# remove the array
	# replace the new line with a comma
	# remove the trailing comma at the end of the line.
	jq -R -c 'split(",") 
		| map({variant: .}) 
		| .[]' <<< "$response"
}

# Fetches all the ATB variants defined in the ATB_ASANA_TASK_ID at the Variants list (comma separated) section.
_fetch_atb_variants() { 
	local url="${asana_api_url}/tasks/${ATB_ASANA_TASK_ID}?opt_fields=notes"
	local atb_variants

	# fetches the items
	# read the response raw
	# select only Variants list section
	# output last line of the input to get all the list of variants.
	atb_variants="$(curl -fSsL ${url} \
		-H "Authorization: Bearer ${ASANA_ACCESS_TOKEN}" \
		| jq -r .data.notes \
		| grep -A1 '^Variants list' \
		| tail -1)"

	variants_list=("$(_create_atb_variant_pairs "$atb_variants")")

	printf "%s\n" "${variants_list[@]}"
}

split_array_into_chunks() {
    local array=("$@")
    local chunk_size=256
    local total_elements=${#array[@]}
    local chunks=()
	local items

    for ((i = 0; i < total_elements; i += chunk_size)); do
		# Format the list of variants in a JSON object suitable for being consumed by GitHub Actions matrix.
		# For more info see https://docs.github.com/en/actions/using-jobs/using-a-matrix-for-your-jobs#example-adding-configurations.
		items="$(echo "${array[@]:i:chunk_size}" |  tr ' ' ',')"
		chunks+=("{\"include\": [${items}]}")
    done

	printf "%s\n" "${chunks[@]}"
}

main() {
	local variants=()
	local items=()

	# fetch ATB variants
	variants+=("$(_fetch_atb_variants)")
	# fetch Origin variants
	variants+=("$(_fetch_origin_tasks "$origin_batch")")

	while read -r variant; do
		items+=("$variant")
	done <<< "$(printf "%s\n" "${variants[@]}")"

	echo "Found ${#items[@]} variants"

	local chunks=()
	while read -r chunk; do
		chunks+=("$chunk")
	done <<< "$(split_array_into_chunks "${items[@]}")"

	local i=1
    for chunk in "${chunks[@]}"; do
		# Save to GitHub output
		echo "Storing chunk #${i}"
		echo "build-variants-${i}=${chunk}" >> "$GITHUB_OUTPUT"
		i=$((i + 1))
    done
}

main "$@"
