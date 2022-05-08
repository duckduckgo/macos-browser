#!/bin/bash

set -eo pipefail

asana_extract_task_id() {
    local task_url_regex='^https://app.asana.com/[0-9]/[0-9]/([0-9]*)/f$'
    if [[ "${asana_task_url}" =~ ${task_url_regex} ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo "Asana Task URL has incorrect format (attempted to match ${task_url_regex})."
        echo
        exit 1
    fi
}

asana_preflight() {
    if [[ -n "${asana_task_url}" ]]; then
        if ! command -v jq &> /dev/null; then
            echo "jq is required to update Asana tasks. Install it with:"
            echo "    $ brew install jq"
            echo
            exit 1
        fi
            
        asana_task_id=$(asana_extract_task_id)
        echo "Will update Asana task ${asana_task_id} after making a build."
    fi
}

asana_preflight