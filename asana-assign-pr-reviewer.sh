#!/bin/bash
#
# This script creates a PR subtask and assign it to a team member when a review is requested on GitHub
# 

set -e -o pipefail

asana_api_url="https://app.asana.com/api/1.0"
pr_prefix="PR:"

ASANA_TASK_ID="1206501971760048"
ASANA_ACCESS_TOKEN=""

ASANA_PR_REVIEWER_ID="1206329551987270"
GITHUB_PR_URL="https://www.example.com"

# Fetch the subtasks of a task with the given ASANA_TASK_ID.
_fetch_subtasks() {
    local url="${asana_api_url}/tasks/${ASANA_TASK_ID}/subtasks?opt_fields=name,completed,parent.name"

    local response="$(curl -fLSs "$url" -H "Authorization: Bearer ${ASANA_ACCESS_TOKEN}")"

    # for each object in the array
    # create a json object with the information we need
    # replace the new line with a comma
	# remove the trailing comma at the end of the line.
    local subtasks=$(jq -c '.data[]
        | {task_id: .gid, task_name: .name, task_completed: .completed, parent_name: .parent.name}' <<< "$response" \
        | tr '\n' ',' \
		| sed 's/,$//')

    echo "[$subtasks]"
}

# Sets the parent task name
_set_parent_task_name() {
    local subtasks=$1

    # extracts the parent name from the first object  
    parent_task_name=$(echo "$subtasks" | jq -r '.[0].parent_name')
}

# Checks if a subtask for the PR already exists.
_check_pr_subtask_exist() {
    local response="$1"

    # read each line of the array
    # extract the task name and trim leading and trailing white spaces
    # extract the parent name and trim leading and trailing white spaces
    # checks if the task name has 'PR:' prefix and if contains the parent name
    echo "$response" | jq -c '.[]' | while read item; do
        task_name=$(jq -r '.task_name' <<< "$item" | awk '{$1=$1};1')
        parent_name=$(jq -r '.parent_name' <<< "$item" | awk '{$1=$1};1')

        if [[ "$task_name" == "${pr_prefix}"* && "$task_name" == *"$parent_name"* ]]; then
            echo "$item"
        fi
    done

}

# Creates a subtask called PR: ${task_title}, set the PR URL as description and assign to the requested reviewer
_create_pr_subtask() {
    local url="${asana_api_url}/tasks/${ASANA_TASK_ID}/subtasks?opt_fields=gid"

    local payload=$(cat <<EOF
    {
        "data": {
            "assignee": "${ASANA_PR_REVIEWER_ID}",
            "notes": "${pr_prefix} ${GITHUB_PR_URL}",
            "name": "${pr_prefix} ${parent_task_name}"
        }
    }
EOF
)

    _execute_create_or_update_asana_task_request POST "$url" "$payload"
}

# Assigns a reviewer to the existing PR subtask and update the task status if it is marked 'completed'
_assign_reviewer_to_existing_pr_subtask_and_update_status() {
    local pr_subtask="$1"
    
    # get the task id
    local task_id=$(echo "$pr_subtask" | jq -r '.task_id')
    # get the completed status
    local task_status_completed=$(echo "$pr_subtask" | jq -r '.task_completed')
    
    local url="${asana_api_url}/tasks/${task_id}?opt_fields=gid"
    local payload=""

    # if the status is completed mark the task uncompleted and assign the reviewer.
    if [ "$task_status_completed" = true ]; then
        payload=$(cat <<EOF
        {
            "data": {
                "assignee": "${ASANA_PR_REVIEWER_ID}",
                "completed": false
            }
        }
EOF
)
    # otherwise just assign the reviewer
    else
        payload=$(cat <<EOF
        {
            "data": {
                "assignee": "${ASANA_PR_REVIEWER_ID}"
            }
        }
EOF
)
    fi

    _execute_create_or_update_asana_task_request PUT "$url" "$payload"
}

# Executes an Asana request to create or update a Subtask
_execute_create_or_update_asana_task_request() {
    local method="$1"
    local url="$2"
    local payload="$3"

    local task_id="$(curl -fLSs -X "$method" "$url" \
        -H "Authorization: Bearer ${ASANA_ACCESS_TOKEN}" \
        -H 'accept: application/json' \
        -H 'content-type: application/json' \
        --data "${payload}" \
        | jq -r .data.gid)"
}

main() {
    # fetch the task subtasks
    local subtasks=$(_fetch_subtasks)

    # set the parent task name
    _set_parent_task_name "$subtasks"

    # check if the PR subtask already exist
    local pr_subtask=$(_check_pr_subtask_exist "$subtasks")

    # if the PR subtask exist, assign the reviewer and mark the task uncompleted the task if it is completed
    # otherwise, create the PR subtask and assign it to the reviewer
    if [[ -n "$pr_subtask" ]]; then
        _assign_reviewer_to_existing_pr_subtask_and_update_status "$pr_subtask"
    else
        _create_pr_subtask
    fi
}

main
