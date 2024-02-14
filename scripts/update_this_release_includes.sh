#!/bin/bash
#
# This script extracts release notes from Asana release task description.
#
# Usage:
#   ./update_this_release_includes.sh <release-task-id>
#

set -e -o pipefail

task_url_regex='^https://app.asana.com/[0-9]/[0-9]*/([0-9]*)/f$'
cwd="$(dirname "${BASH_SOURCE[0]}")"
release_task_id="$1"

if [[ -z "$release_task_id" ]]; then
	echo "Usage: $0 <release-task-id>"
	exit 1
fi

get_task_id() {
	local url="$1"
	if [[ "$url" =~ ${task_url_regex} ]]; then
		echo "${BASH_REMATCH[1]}"
	fi
}

fetch_current_release_notes() {
	curl -fLSs "https://app.asana.com/api/1.0/tasks/${release_task_id}?opt_fields=notes" \
		-H "Authorization: Bearer ${ASANA_ACCESS_TOKEN}" \
		| jq -r .data.notes \
		| "${cwd}"/extract_release_notes.sh
}

construct_task_description() {
	local release_notes=("$@")
	local escaped_release_note
	printf '%s' '<body><h1>Release notes</h1>'
	if [[ -n "${release_notes[*]}" ]]; then
		printf '%s' '<ul>'
		for release_note in "${release_notes[@]}"; do
			escaped_release_note="$(sed -e 's/</\&lt;/g' -e 's/>/\&gt;/g' <<< "${release_note}")"
			printf '%s' "<li>${escaped_release_note}</li>"
		done
		printf '%s' '</ul>'
	fi

	printf '%s' '<h2>This release includes:</h2>'

	# if task_urls is not empty
	if [[ -n "${task_urls[*]}" ]]; then
		printf '%s' '<ul>'
		for url in "${task_urls[@]}"; do
			task_id=$(get_task_id "$url")
			if [[ -n "$task_id" ]]; then
				printf '%s' "<li><a data-asana-gid='${task_id}'/></li>"
			fi
		done
		printf '%s' '</ul>'
	fi

	printf '%s' '</body>'
}

fetch_task_urls() {
	git fetch -q --tags
	last_release_tag="$(gh api /repos/duckduckgo/macos-browser/releases/latest --jq .tag_name)"

	task_urls=
	# shellcheck disable=SC2046
	read -ra task_urls <<< $(git log "${last_release_tag}"..HEAD | grep 'Task.*URL' | awk '{ print $3; }' | grep asana | uniq)
}

main() {
	fetch_task_urls
	local release_notes=()
	local html_notes
	local request_payload
	# shellcheck disable=SC2046
	while read -r line; do
		release_notes+=("$line")
	done <<< "$(fetch_current_release_notes)"
	html_notes="$(construct_task_description "${release_notes[@]}")"
	request_payload="{\"data\":{\"html_notes\":\"${html_notes}\"}}"

	curl -fLSs -X PUT "https://app.asana.com/api/1.0/tasks/${release_task_id}?opt_fields=permalink_url" \
		-H 'Content-Type: application/json' \
		-H "Authorization: Bearer ${ASANA_ACCESS_TOKEN}" \
		-d "$request_payload"
}

main