#!/bin/bash
#
# This scripts 
# 

set -e -o pipefail

asana_api_url="https://app.asana.com/api/1.0"
parent_task_name=""

ASANA_TASK_ID="1206501971760048" #"1207032959154811"
ASANA_ACCESS_TOKEN="2/1206329551987270/1206904223324738:1c68ff7d9f9afcdb84089276681dbc47"

ASANA_PR_REVIEWER_ID="1206329551987270"
GITHUB_PR_URL="https://www.example.com"

# Fetch the subtasks of the task.
_fetch_subtasks() {
    local url="${asana_api_url}/tasks/${ASANA_TASK_ID}/subtasks?opt_fields=name,completed,parent.name"

    response="$(curl -fLSs "$url" -H "Authorization: Bearer ${ASANA_ACCESS_TOKEN}")"

    jq -r '.data[]
        | {task_id: .gid, task_name: .name, task_completed: .completed, parent_name: .parent.name}' <<< "$response"
}

_check_pr_subtask_exist() {
    local response="$1"
    local pr_prefix="PR:"
    local task=""

    while IFS= read -r item; do
        task_name=$(jq -r '.task_name' <<< "$item")
        sanitised_task_name=${task_name//$pr_prefix/}
        parent_name=$(jq -r '.parent_name' <<< "$item")
        parent_task_name="${parent_name}"

        if [[ "$parent_name" == *"$sanitised_task_name"* ]]; then
            task="${item}"
        fi
    done <<< "$response"

    echo "${task}"
}

# Create a subtask called PR: ${task_title}, set the PR URL as description and assign to the requested reviewer
_create_pr_subtask() {
    local url="${asana_api_url}/tasks/${ASANA_TASK_ID}/subtasks?opt_fields=gid"

    local payload="
    {
        \"data\": {
            \"assignee\": \""${ASANA_PR_REVIEWER_ID}"\",
            \"notes\": \"PR: "${GITHUB_PR_URL}"\",
            \"name\": \"PR: "${parent_task_name}"\"
        }
    }
    "

    local task_id="$(curl -fLSs "$url" \
        -H "Authorization: Bearer ${ASANA_ACCESS_TOKEN}" \
        -H 'accept: application/json' \
        -H 'content-type: application/json' \
        --data "${payload}" \
        | jq -r .data.gid)"
}

_assign_reviewer_to_pr_subtask_and_update_status() {
    local pr_subtask="$1"
    local task_id=$(echo "$pr_subtask" | jq -r '.task_id')
    local task_status_completed=$(echo "$pr_subtask" | jq -r '.task_completed')
    local url="${asana_api_url}/tasks/${task_id}?opt_fields=gid"

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

    echo ""$url""
    echo ""$payload""

    local task_id="$(curl -fLSs -X PUT "$url" \
        -H "Authorization: Bearer ${ASANA_ACCESS_TOKEN}" \
        -H 'accept: application/json' \
        -H 'content-type: application/json' \
        --data "${payload}" \
        | jq -r .data.gid)"
}

main() {
    # Fetch the task subtasks
    #local subtasks=$(_fetch_subtasks)

    local subtasks='{"task_id": "1207133700894325","task_name": "PR: Show Bookmark All Tabs… - Translate Copy", "task_completed": true, "parent_name": "🕵️‍♂️ Show Bookmark All Tabs… - Translate Copy - 0.5 day"}'

    #local subtasks='{"task_id": "1206501971760063","task_name": "Task Timeline","parent_name": "Project Scope - Bookmark all open tabs"}'

    # Check if the PR subtask already exist
    local pr_subtask=$(_check_pr_subtask_exist "$subtasks")

    if [[ -n "$pr_subtask" ]]; then
        echo "PR subtask found: $pr_subtask"
        # If the PR subtask exists, assign it to the requested reviewer and update task status if it is marked completed.
        _assign_reviewer_to_pr_subtask_and_update_status "$pr_subtask"
    else
        echo "PR subtask not found"
        #Create a subtask called PR: ${task_title}, set the PR URL as description and assign to the requested reviewer.
        _create_pr_subtask
    fi
}

subtask='{"task_id": "1206501971760052","task_name": "Get familiar with Bookmarks codebase - 1 day","task_completed":true,"parent_name": "Project Scope - Bookmark all open tabs"}'
_assign_reviewer_to_pr_subtask_and_update_status "$subtask"
