#!/bin/bash
#
# This script updates "This release includs:" section of the release task
# with the list of Asana tasks linked in git commit messages since the last
# official release tag.
#
# Note: this script is intended to be run in CI environment and should not
# be run locally as part of the release process.
#
# Usage:
#   ./update_this_release_includes.sh <release-task-id> <validation-section-id>
#

set -e -o pipefail

asana_api_url="https://app.asana.com/api/1.0"
task_url_regex='^https://app.asana.com/[0-9]/[0-9]*/([0-9]*)/f$'
cwd="$(dirname "${BASH_SOURCE[0]}")"

find_task_urls_in_git_log() {
	git fetch -q --tags
	last_release_tag="$(gh api /repos/duckduckgo/macos-browser/releases/latest --jq .tag_name)"

	git log "${last_release_tag}"..HEAD | grep 'Task.*URL' | awk '{ print $3; }' | grep asana | uniq
}

fetch_current_release_notes() {
	local release_task_id="$1"
	curl -fLSs "${asana_api_url}/tasks/${release_task_id}?opt_fields=notes" \
		-H "Authorization: Bearer ${ASANA_ACCESS_TOKEN}" \
		| jq -r .data.notes \
		| "${cwd}"/extract_release_notes.sh
}

get_task_id() {
	local url="$1"
	if [[ "$url" =~ ${task_url_regex} ]]; then
		echo "${BASH_REMATCH[1]}"
	fi
}

construct_task_description() {
	local escaped_release_note
	printf '%s' "<body><strong>Note: This task's description is managed automatically.</strong>\n"
	printf '%s' 'Only the <em>Release notes</em> section below should be modified manually.\n'
	printf '%s' 'Please do not adjust formatting.<h1>Release notes</h1>'
	if [[ -n "${release_notes[*]}" ]]; then
		printf '%s' '<ul>'
		for release_note in "${release_notes[@]}"; do
			escaped_release_note="$(sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' <<< "${release_note}")"
			printf '%s' "<li>${escaped_release_note}</li>"
		done
		printf '%s' '</ul>'
	fi

	printf '%s' '<h2>This release includes:</h2>'

	if [[ -n "${task_ids[*]}" ]]; then
		printf '%s' '<ul>'
		for task_id in "${task_ids[@]}"; do
			printf '%s' "<li><a data-asana-gid=\\\"${task_id}\\\"/></li>"
		done
		printf '%s' '</ul>'
	fi

	printf '%s' '</body>'
}

update_task_description() {
	local html_notes="$1"
	local request_payload="{\"data\":{\"html_notes\":\"${html_notes}\"}}"

	curl -fLSs -X PUT "${asana_api_url}/tasks/${release_task_id}?opt_fields=permalink_url" \
		-H 'Content-Type: application/json' \
		-H "Authorization: Bearer ${ASANA_ACCESS_TOKEN}" \
		-d "$request_payload" | jq -r .data.permalink_url
}

move_tasks_to_section() {
	local section_id="$1"
	shift
	local task_ids=("$@")

	for task_id in "${task_ids[@]}"; do
		curl -fLSs "${asana_api_url}/sections/${section_id}/addTask" \
			-H 'Content-Type: application/json' \
			-H "Authorization: Bearer ${ASANA_ACCESS_TOKEN}" \
			--write-out '%{http_code}' \
			--output /dev/null \
			-d "{\"data\": {\"task\": \"${task_id}\"}}"
	done
}

main() {
	local release_task_id="$1"
	local validation_section_id="$2"

	if [[ -z "$release_task_id" ]]; then
		echo "Usage: $0 <release-task-id>"
		exit 1
	fi

	# 1. Fetch task URLs from git commit messages
	task_ids=()
	while read -r line; do
		task_ids+=("$(get_task_id "$line")")
	done <<< "$(find_task_urls_in_git_log)"

	# 2. Fetch current release notes from Asana release task.
	release_notes=()
	while read -r line; do
		release_notes+=("$line")
	done <<< "$(fetch_current_release_notes "${release_task_id}")"

	# 3. Construct new release task description
	local html_notes
	html_notes="$(construct_task_description)"

	# 4. Update release task description
	update_task_description "$html_notes"

	# 5. Move all tasks (including release task itself) to the validation section
	task_ids+=("${release_task_id}")
	move_tasks_to_section "$validation_section_id" "${task_ids[@]}"
}

main "$@"