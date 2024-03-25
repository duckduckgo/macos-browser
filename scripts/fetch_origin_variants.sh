#!/bin/bash
#
# This scripts fetches Asana tasks from the Origins section defined in the Asana project https://app.asana.com/0/1206716555947156/1206716715679835.
# 

set -e -o pipefail

section_id="1206716555947176"
# TODO: Pass this as Environment Variable
ASANA_ACCESS_TOKEN="2/1206329551987270/1206904223324738:1c68ff7d9f9afcdb84089276681dbc47"

# Create a JSON string with the `origin-variant` pairs.
_extract_origins_and_variants() {
    local response="$1"
    local origin_field="Origin"
    local atb_field="ATB"
    
    jq -c '.data[]
        | select(.custom_fields[] | select(.name == "'"${origin_field}"'").text_value != null)
        | {origin: (.custom_fields[] | select(.name == "'"${origin_field}"'") | .text_value), variant: (.custom_fields[] | select(.name == "'"${atb_field}"'") | .text_value)}
        | del(.variant | nulls)' <<< "$response" \
        | tr '\n' ',' | sed 's/,$//' #concatenates the pair by a comma and remove the trailing comma at the end of the line.
}

# Fetch all the Asana tasks for a specific section of a project.
# This function fetches only uncompleted tasks.
# If there are more than 100 items the function takes care of pagination.
# Returns a JSON string consisting of a list of `origin-variant` pairs concatenated by a comma. Eg. `{"origin":"app","variant":"ab"},{"origin":"app.search","variant":null}`.  
_fetch_tasks() {
    local asana_api_url="https://app.asana.com/api/1.0"
    # Fetches only tasks that have not been completed yet, includes in the response section name, name of the task and its custom fields. 
    local query="completed_since=now&opt_fields=name,custom_fields.id_prefix,custom_fields.name,custom_fields.text_value&opt_expand=custom_fields&opt_fields=memberships.section.name&limit=100"

    local url="${asana_api_url}/sections/${section_id}/tasks?${query}"
    local response
    local data=()

    # go through all tasks in the section (there may be multiple requests in case there are more than 100 tasks in the section)
	# repeat until no more pages (next_page.uri is null)
    while true; do
        response="$(curl -fLSs "$url" -H "Authorization: Bearer ${ASANA_ACCESS_TOKEN}")"
        
        # extract the object in the data array and append to result
        data+=("$(_extract_origins_and_variants "$response")")

        # set new URL to next page URL
        url="$(jq -r .next_page.uri <<< "$response")"

		# break on last page
		if [[ "$url" == "null" ]]; then
			break
		fi
    done

    echo "DATA "${data}""
}

main() {
    # Fetch all tasks in 
    _fetch_tasks
}

main 
