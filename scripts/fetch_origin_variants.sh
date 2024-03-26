#!/bin/bash
#
# This scripts fetches Asana tasks from the Origins section defined in the Asana project https://app.asana.com/0/1206716555947156/1206716715679835.
# 

set -e -o pipefail

asana_api_url="https://app.asana.com/api/1.0"

# TODO: Pass these as Environment Variable
ASANA_ACCESS_TOKEN="2/1206329551987270/1206904223324738:1c68ff7d9f9afcdb84089276681dbc47"
ORIGIN_ASANA_SECTION_ID="1206716555947176"
ATB_ASANA_TASK_ID="1205370183939342"

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
        | if .variant != null then {origin}, {origin, variant} else {origin} end' <<< "$response" \
        | tr '\n' ',' \
        | sed 's/,$//'
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

    echo "${origin_variants}"
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
    | .[]' <<< "$response" \
    | tr '\n' ',' \
    | sed 's/,$//'
}

# Fetches all the ATB variants defined in the ATB_ASANA_TASK_ID at the Variants list (comma separated) section.
_fetch_atb_variants() {
    local url="${asana_api_url}/tasks/${ATB_ASANA_TASK_ID}?opt_fields=notes"
    local atb_variants

    atb_variants="$(curl -fSsL ${url} \
    -H "Authorization: Bearer ${ASANA_ACCESS_TOKEN}" \
    | jq -r .data.notes \
    | grep -A1 '^Variants list' \
    | tail -1)"

    variants_list=("$(_create_atb_variant_pairs "$atb_variants")")

    echo "${variants_list}"
}

main() {
    # fetch ATB variants
    local atb_variants=$(_fetch_atb_variants)
    # fetch
    local origin_variants=$(_fetch_origin_tasks)

    echo "ATB: "${atb_variants}""
    echo "ORIGIN: "${origin_variants}""

    local output="${atb_variants},${origin_variants}"

    echo "OUTPUT: "${output}""
}

main 
