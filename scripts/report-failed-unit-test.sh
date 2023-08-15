#!/bin/bash

set -eo pipefail

if ! [[ $common_sh ]]; then
	cwd="$(dirname "${BASH_SOURCE[0]}")"
	source "${cwd}/helpers/common.sh"
fi

print_usage_and_exit() {
	local reason=$1

	cat <<- EOF
	Usage:
	  $ $(basename "$0") [-h] <class_name> <testcase_name> <message> <workflow_url>

	Options:
	  <class_name>       Name of the failing test case class
	  <testcase_name>    Name of the failing test case
	  <message>          Failure message
	  <workflow_url>     URL of the workflow that failed
	  -h                 Print this message

	Note: This script is intended for CI use only. You shouldn't call it directly.
	EOF

	die "${reason}"
}

read_command_line_arguments() {
	while getopts 'h' OPTION; do
		case "${OPTION}" in
			h)
				print_usage_and_exit
				;;
			*)
				print_usage_and_exit "Unknown option '${OPTION}'"
				;;
		esac
	done

	shift $((OPTIND-1))

	if (( $# < 4 )); then
		print_usage_and_exit "Missing arguments"
	fi

	class_name=$1
	testcase_name=$2
	message=$3
	workflow_url=$4

	shift 4
}

workspace_id="137249556945"
project_id="1205237866452338"
occurrences_custom_field_id="1205237866452341"
failing_tests_section_id="1205242009579904"
asana_api_url="https://app.asana.com/api/1.0"

find_task_and_occurrences() {
	local task_name=$1
	curl -s "${asana_api_url}/workspaces/${workspace_id}/tasks/search?text=${task_name}&opt_fields=custom_fields.number_value&resource_subtype=default_task&projects.any=${project_id}&is_subtask=false" \
		-H "Authorization: Bearer ${asana_personal_access_token}" \
		| jq -r "if (.data | length) != 0 then [.data[0].gid, (.data[0].custom_fields[] | select(.gid == \"${occurrences_custom_field_id}\") | (.number_value // 0))] | join(\" \") else empty end"
}

update_task() {
	local task_id=$1
	local occurrences=$2
	local return_code

	return_code="$(curl -X PUT -s "${asana_api_url}/tasks/${task_id}" \
		-H "Authorization: Bearer ${asana_personal_access_token}" \
     	-H 'content-type: application/json' \
		--write-out '%{http_code}' \
		--output /dev/null \
		-d "{
				\"data\": {
					\"completed\": false,
					\"custom_fields\": {
						\"${occurrences_custom_field_id}\": \"${occurrences}\"
					},
					\"due_on\": \"${due_date}\"
				}
			}")"

	[[ ${return_code} -eq 200 ]]
}

create_task() {
	local task_name=$1
	local workflow_url=$2
	local message="${3//\"/\\\"}"
	local occurrences=1
	local task_id

	task_id=$(curl -X POST -s "${asana_api_url}/tasks?opt_fields=gid" \
		-H "Authorization: Bearer ${asana_personal_access_token}" \
		-H 'content-type: application/json' \
		-d "{
				\"data\": {
					\"custom_fields\": {
						\"${occurrences_custom_field_id}\": \"${occurrences}\"
					},
					\"due_date\": \"${due_date}\",
					\"name\": \"${task_name}\",
					\"resource_subtype\": \"default_task\",
					\"notes\": \"Workflow URL: ${workflow_url}\n\n${message}\",
					\"projects\": [
						\"${project_id}\"
					],
					\"workspace\": \"${workspace_id}\"
				}
			}" \
		| jq -r '.data.gid')

	curl -X POST -s "${asana_api_url}/sections/${failing_tests_section_id}/addTask" \
		-H "Authorization: Bearer ${asana_personal_access_token}" \
		-H 'content-type: application/json' \
		--write-out '%{http_code}' \
		--output /dev/null \
	    -d "{\"data\": {\"task\": \"${task_id}\"}}"
}

add_subtask() {
	local parent_task_id=$1
	local task_name=$2
	local workflow_url=$3
	local message="${4//\"/\\\"}"
	local return_code

	return_code=$(curl -X POST -s "${asana_api_url}/tasks/${parent_task_id}/subtasks" \
		-H "Authorization: Bearer ${asana_personal_access_token}" \
    	-H 'content-type: application/json' \
		--write-out '%{http_code}' \
		--output /dev/null \
     	-d "{
				\"data\": {
    				\"name\": \"${task_name}\",
    				\"resource_subtype\": \"default_task\",
    				\"notes\": \"Workflow URL: ${workflow_url}\n\n${message}\"
  				}
			}
		")

	[[ ${return_code} -eq 201 ]]
}

main() {
	local class_name
	local testcase_name
	local message
	local workflow_url
	local due_date
	due_date=$(date -v +30d +%Y-%m-%d)

	source "${cwd}/helpers/keychain.sh"
	read_command_line_arguments "$@"
	
	# Load Asana-related functions. This calls `_asana_preflight` which
	# will check for Asana access token if needed (if asana task was passed to the script).
	source "${cwd}/helpers/asana.sh"

	_asana_get_token

	local task_name="${class_name}.${testcase_name}"
	echo "Processing ${task_name}"

	local task_and_occurrences
	task_and_occurrences=$(find_task_and_occurrences "${task_name}")
	if [[ -n "${task_and_occurrences}" ]]; then
		local task_id
		local occurrences
		task_id=$(cut -d ' ' -f 1 <<< "${task_and_occurrences}")
		occurrences=$(cut -d ' ' -f 2 <<< "${task_and_occurrences}")
		occurrences=$((occurrences+1))

		update_task "${task_id}" "${occurrences}"
		add_subtask "${task_id}" "${task_name}" "${workflow_url}" "${message}"
	else
		create_task "${task_name}" "${workflow_url}" "${message}"
	fi
}

main "$@"
