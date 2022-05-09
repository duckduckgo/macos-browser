#!/bin/bash

set -eo pipefail

asana_token_keychain_identifier="asana-personal-token"

asana_preflight() {
    if [[ -n "${asana_task_url}" ]]; then
        if ! command -v jq &> /dev/null; then
            echo "jq is required to update Asana tasks. Install it with:"
            echo "    $ brew install jq"
            echo
            exit 1
        fi

        asana_task_id=$(asana_extract_task_id)
        asana_get_token

        echo "Will update Asana task ${asana_task_id} after making a build."
    fi
}

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

asana_get_token() {
    asana_personal_access_token="${ASANA_ACCESS_TOKEN}"

    if [[ -z "${asana_personal_access_token}" ]]; then

        if user_has_password_in_keychain "${asana_token_keychain_identifier}"; then
            echo "Found Asana Personal Access Token in the keychain"
            asana_personal_access_token=$(retrieve_password_from_keychain "${asana_token_keychain_identifier}")
        else
            while [[ -z "${asana_personal_access_token}" ]]; do
                echo "Input your Asana Personal Access Token. It will be stored securely in the keychain."
                echo
                read -srp "Your Asana Personal Access Token: " asana_personal_access_token
                echo
            done

            store_password_in_keychain "${asana_token_keychain_identifier}" "${asana_personal_access_token}"
        fi
    fi
}

asana_upload_dmg() {
    local dmg_path=$1
    local dmg_name
    dmg_name="$(basename "${dmg_path}")"

    return_code="$(curl -s "${asana_api_url}/tasks/${asana_task_id}/attachments" \
        -H "Authorization: Bearer ${asana_personal_access_token}" \
        --write-out '%{http_code}' \
        --output /dev/null \
        --form "file=@${dmg_path};type=application/octet-stream&name=${dmg_name}")"

    [[ $return_code -eq 200 ]]
}

asana_upload_dsyms_zip() {
    local dsyms_path=$1
    local dsyms_name
    dsyms_name="$(basename "${dsyms_path}")"

    return_code="$(curl -s "${asana_api_url}/tasks/${asana_task_id}/attachments" \
        -H "Authorization: Bearer ${asana_personal_access_token}" \
        --write-out '%{http_code}' \
        --output /dev/null \
        --form "file=@${dsyms_path};type=application/zip&name=${dsyms_name}")"

    [[ $return_code -eq 200 ]]
}

asana_complete_task() {
    local task_id=$1
    
    return_code="$(curl -s "${asana_api_url}/tasks/${task_id}" \
        -H "Authorization: Bearer ${asana_personal_access_token}" \
        -H 'Content-Type: application/json' \
        --write-out '%{http_code}' \
        --output /dev/null \
        -X PUT \
        -d '{"data":{"completed":true}}')"
    
    [[ ${return_code} -eq 200 ]]
}

asana_get_subtasks() {
    curl -s "${asana_api_url}/tasks/${asana_task_id}/subtasks" \
        -H "Authorization: Bearer ${asana_personal_access_token}"
}

asana_get_subtask_id() {
    local task_name=$1
    jq ".data[] | select(.name | test(\"${task_name}\")) | .gid" <<< "${tasks}" | tr -d '"'
}

asana_update_task() {
    local dmg_path=$1
    local dsym_zip_path=$2
    local asana_api_url="https://app.asana.com/api/1.0"
    
    echo
    printf '%s' "Uploading DMG to Asana task ... "

    if asana_upload_dmg "${dmg_path}"; then
        echo "Done"
    else
        echo "Failed to upload DMG to Asana"
        echo
        exit 1
    fi

    printf '%s' "Uploading dSYMs zip to Asana task ... "

    if asana_upload_dsyms_zip "${dsym_zip_path}"; then
        echo "Done"
    else
        echo "Failed to upload dSYMs zip to Asana"
        echo
        exit 1
    fi

    local tasks_to_update=(
        "Create Release Build using GitHub Action"
        "Upload symbols"
        "Create DMG with background"
        "Upload DMG to this release task"
    )

    local tasks
    tasks="$(asana_get_subtasks)"
    
    for task in "${tasks_to_update[@]}"; do

        printf '%s' "Marking task '${task}' as complete ... "
        task_id="$(asana_get_subtask_id "${task}")"
        if asana_complete_task "${task_id}"; then
            echo "Done"
        else
            echo "Failed"
            echo
            exit 1
        fi

    done

}

asana_preflight