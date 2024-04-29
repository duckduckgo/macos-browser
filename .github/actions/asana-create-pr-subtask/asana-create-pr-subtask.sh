#!/bin/bash
#
# This script creates a PR subtask and assign it to a team member when a review is requested on GitHub
# 

set -e -o pipefail

asana_api_url="https://app.asana.com/api/1.0"
pr_prefix="PR:"

# Fetch the subtasks of a task with the given Asana task ID.
_fetch_subtasks() {
	local asana_task_id="$1"
	local url="${asana_api_url}/tasks/${asana_task_id}/subtasks?opt_fields=name,completed,parent.name,assignee"

	local response
	response="$(curl -fLSs "$url" -H "Authorization: Bearer ${ASANA_ACCESS_TOKEN}")"

	# extract the task id, task name, task completed status, assignee id and parent name
	jq -c '[
		.data[] | {
			task_id: .gid,
			task_name: .name,
			task_completed: .completed,
			assignee: .assignee.gid,
			parent_name: .parent.name
		}
	]' <<< "$response"
}

# Sets the parent task name
_set_parent_task_name() {
	local subtasks="$1"
	local asana_task_id="$2"

	# extracts the parent name from the first object  
	parent_task_name=$(echo "$subtasks" | jq -r '.[0].parent_name')

	# if parent_task_name is nil it means that there are no subtask in the current task so we fetch the parent name
	if [ -z "$parent_task_name" ] || [ "$parent_task_name" = "null" ]; then
		local url="${asana_api_url}/tasks/${asana_task_id}"
		parent_task_name="$(curl -fLSs "$url" -H "Authorization: Bearer ${ASANA_ACCESS_TOKEN}" | jq -r '.data.name')"
	fi
}

# Checks if a subtask for the PR already exists.
_check_pr_subtask_exist() {
	local response="$1"
	local asana_assignee_id="$2"

	# read each line of the array
	# extract the task name and trim leading and trailing white spaces
	# extract the parent name and trim leading and trailing white spaces
	# extract the assignee name
	# checks if the task name has 'PR:' prefix and if contains the parent name and if it's assigned to the reviewer
	echo "$response" | jq -c '.[]' | while read -r item; do
		task_name=$(jq -r '.task_name' <<< "$item" | awk '{$1=$1};1')
		parent_name=$(jq -r '.parent_name' <<< "$item" | awk '{$1=$1};1')
		assignee=$(jq -r '.assignee' <<< "$item")

		if [[ "$task_name" == "${pr_prefix}"* && "$task_name" == *"$parent_name"* && "$assignee" == "$asana_assignee_id" ]]; then
			echo "$item"
		fi
	done

}

# Creates a subtask called PR: ${task_title}, set the PR URL as description and assign to the requested reviewer
_create_pr_subtask() {
	local asana_task_id="$1"
	local asana_assignee_id="$2"
	local github_pr_url="$3"
	local url="${asana_api_url}/tasks/${asana_task_id}/subtasks?opt_fields=gid"

	local payload
	payload=$(cat <<EOF
	{
		"data": {
			"assignee": "${asana_assignee_id}",
			"notes": "${pr_prefix} ${github_pr_url}",
			"name": "${pr_prefix} ${parent_task_name}"
		}
	}
EOF
)

	_execute_create_or_update_asana_task_request POST "$url" "$payload"
}

# Assigns a reviewer to the existing PR subtask and update the task status if it is marked 'completed'
_mark_task_uncompleted_if_needed() {
	local pr_subtask="$1"
	
	# get the task id
	local task_id
	task_id=$(echo "$pr_subtask" | jq -r '.task_id')
	# get the completed status
	local task_status_completed
	task_status_completed=$(echo "$pr_subtask" | jq -r '.task_completed')
	
	# if the status is completed mark the task uncompleted.
	if [ "$task_status_completed" = true ]; then
		local url="${asana_api_url}/tasks/${task_id}?opt_fields=gid"
		local payload='{"data":{"completed":false}}'
		_execute_create_or_update_asana_task_request PUT "$url" "$payload"
	fi
}

# Executes an Asana request to create or update a Subtask
_execute_create_or_update_asana_task_request() {
	local method="$1"
	local url="$2"
	local payload="$3"

	local task_id
	task_id="$(curl -fLSs -X "$method" "$url" \
		-H "Authorization: Bearer ${ASANA_ACCESS_TOKEN}" \
		-H 'accept: application/json' \
		-H 'content-type: application/json' \
		--data "${payload}" \
		| jq -r .data.gid)"
}

main() {
	local asana_task_id="$1"
	local asana_assignee_id="$2"
	local github_pr_url="$3"

	# fetch the task subtasks
	local subtasks
	subtasks=$(_fetch_subtasks "$asana_task_id")

	# set the parent task name
	_set_parent_task_name "$subtasks" "$asana_task_id"

	# check if the PR subtask already exist
	local pr_subtask
	pr_subtask=$(_check_pr_subtask_exist "$subtasks" "$asana_assignee_id")

	# if the PR subtask exist, mark the task uncompleted if it the task is marked completed
	# otherwise, create the PR subtask and assign it to the reviewer
	if [[ -n "$pr_subtask" ]]; then
		_mark_task_uncompleted_if_needed "$pr_subtask"
	else
		_create_pr_subtask "$asana_task_id" "$asana_assignee_id" "$github_pr_url"
	fi
}

main "$@"
