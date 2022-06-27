#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
asana_token_keychain_identifier="asana-personal-token"

asana_update_task() {
	local dmg_path=$1
	local dsym_zip_path=$2
	local asana_api_url="https://app.asana.com/api/1.0"
	
	echo
	printf '%s' "Uploading DMG to Asana task ... "

	if _asana_upload_dmg "${dmg_path}"; then
		echo "Done"
	else
		die "Failed to upload DMG to Asana"
	fi

	printf '%s' "Uploading dSYMs zip to Asana task ... "

	if _asana_upload_dsyms_zip "${dsym_zip_path}"; then
		echo "Done"
	else
		die "Failed to upload dSYMs zip to Asana"
	fi

	_asana_close_subtasks
}

# Private

#
# Verify that required software is installed and fetch Asana access token
#
_asana_preflight() {
	if [[ -n "${asana_task_url}" ]]; then
		if ! command -v jq &> /dev/null; then
			cat <<- EOF
			jq is required to update Asana tasks. Install it with:
			  $ brew install jq
			
			EOF
			die
		fi

		asana_task_id=$(_asana_extract_task_id)
		_asana_get_token

		echo "Will update Asana task ${asana_task_id} after making a build."
	fi
}

_asana_extract_task_id() {
	local task_url_regex='^https://app.asana.com/[0-9]/[0-9]*/([0-9]*)/f$'
	if [[ "${asana_task_url}" =~ ${task_url_regex} ]]; then
		echo "${BASH_REMATCH[1]}"
	else
		die "Asana Task URL has incorrect format (attempted to match ${task_url_regex})."
	fi
}

#
# If ASANA_ACCESS_TOKEN environment variable is defined, use it,
# otherwise check keychain or ask user if not found in keychain.
#
_asana_get_token() {
	asana_personal_access_token="${ASANA_ACCESS_TOKEN}"

	if [[ -z "${asana_personal_access_token}" ]]; then

		if is_item_in_keychain "${asana_token_keychain_identifier}"; then
			echo "Found Asana Personal Access Token in the keychain"
			asana_personal_access_token=$(retrieve_item_from_keychain "${asana_token_keychain_identifier}")
		else
			while [[ -z "${asana_personal_access_token}" ]]; do
				echo "Input your Asana Personal Access Token. It will be stored securely in the keychain."
				echo
				read -srp "Your Asana Personal Access Token: " asana_personal_access_token
				echo
			done

			store_item_in_keychain "${asana_token_keychain_identifier}" "${asana_personal_access_token}"
		fi
	fi
}

_asana_upload_dmg() {
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

_asana_upload_dsyms_zip() {
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

_asana_complete_task() {
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

#
# Use hardcoded tag ID (for `apple-gha-automate` tag) to find relevant subtasks.
# Use jq to format the output into space-separated task IDs.
#
_asana_get_subtasks_to_close() {
	local tag_id="1202251744337353"
	curl -s "${asana_api_url}/tasks/${asana_task_id}/subtasks?opt_fields=tags,name" \
		-H "Authorization: Bearer ${asana_personal_access_token}" \
		| jq "[.data[] | select(.tags[0].gid == \"${tag_id}\") | .gid] | join(\" \")" \
		| tr -d '"'
}

#
# For simplicity, die if any of the tasks fails to close.
#
_asana_close_subtasks() {
	local subtasks_to_close
	read -ra subtasks_to_close <<< "$(_asana_get_subtasks_to_close)"

	if [[ -n "${subtasks_to_close[*]}" ]]; then

		printf '%s' "Marking ${#subtasks_to_close[@]} relevant Asana task(s) as complete ... "
	
		for task_id in "${subtasks_to_close[@]}"; do
			if ! _asana_complete_task "${task_id}"; then
				die "Failed"
			fi
		done

		echo "Done"
		echo
	fi
}

# Script

_asana_preflight
