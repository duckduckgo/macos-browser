#!/bin/bash
#
# This scripts updates Asana tasks related to the release:
# - Updates "This release includes:" section of the release task with the list
#	of Asana tasks linked in git commit messages since the last official release tag.
# - Moves all tasks (including the release task itself) to the section
#	in macOS App Board project identified by the target-section-id argument
#   (Validation for internal releases, Done for public/hotfix releases).
# - Tags all tasks with the release tag (creating the tag as needed).
# - Closes all tasks that don't require a post-mortem, based on the following criteria:
#   - Task does not belong to Current Objectives project
#   - Task is not a subtask of SRE for Native Apps Engineering task (where incidents are kept)
#
# Note: this script is intended to be run in CI environment and should not
# be run locally as part of the release process.
#
# Usage:
#   ./update_asana_for_release.sh <release-type> <release-task-id> <target-section-id> <marketing-version> [announcement-task-contents-file]
#

set -e -o pipefail

workspace_id="137249556945"
asana_api_url="https://app.asana.com/api/1.0"
task_url_regex='^https://app.asana.com/[0-9]/[0-9]*/([0-9]*)(:?/f)?$'
default_incidents_parent_task_id="1135688560894081"
default_current_objectives_project_id="72649045549333"
cwd="$(dirname "${BASH_SOURCE[0]}")"

find_task_urls_in_git_log() {
	local last_release_tag="$1"

	git fetch -q --tags

	# 1. Fetch all commit messages since the last release tag
	# 2. Extract Asana task URLs from the commit messages
	#    (Use -A 1 to handle cases where URL is on the next line after "Task/Issue URL:")
	# 3. Filter only lines containing Asana URLs
	# 4. Remove duplicates
	git log "${last_release_tag}"..HEAD \
		| grep -A 1 'Task.*URL' \
		| sed -nE 's|.*(https://app\.asana\.com.*)|\1|p' \
		| uniq
}

fetch_current_release_notes() {
	local release_task_id="$1"
	curl -fLSs "${asana_api_url}/tasks/${release_task_id}?opt_fields=notes" \
		-H "Authorization: Bearer ${ASANA_ACCESS_TOKEN}" \
		| jq -r .data.notes \
		| "${cwd}"/extract_release_notes.sh -a
}

get_task_id() {
	local url="$1"
	if [[ "$url" =~ ${task_url_regex} ]]; then
		local task_id="${BASH_REMATCH[1]}"
		local http_code
		http_code="$(curl -fLSs "${asana_api_url}/tasks/${task_id}?opt_fields=gid" \
			-H "Authorization: Bearer ${ASANA_ACCESS_TOKEN}" \
			--write-out '%{http_code}' \
			--output /dev/null)"
		if [[ "$http_code" -eq 200 ]]; then
			echo "${task_id}"
		else
			echo ""
		fi
	fi
}

construct_this_release_includes() {
	if [[ -n "${task_ids[*]}" ]]; then
		printf '%s' '<ul>'
		for task_id in "${task_ids[@]}"; do
			if [[ "$task_id" != "$release_task_id" ]]; then
				printf '%s' "<li><a data-asana-gid=\"${task_id}\"/></li>"
			fi
		done
		printf '%s' '</ul>'
	fi
}

construct_release_task_description() {
	printf '%s' "<body><strong>Note: This task's description is managed automatically.</strong>\n"
	printf '%s' 'Only the <em>Release notes</em> section below should be modified manually.\n'
	printf '%s' 'Please do not adjust formatting.'

	printf '%s' '<h1>Release notes</h1>'
	printf '%s' "$release_notes"

	printf '%s' '<h2>This release includes:</h2>'
	construct_this_release_includes

	printf '%s' '</body>'
}

construct_release_announcement_task_description() {
	printf '%s' "<body>As the last step of the process, post a message to <a href='https://app.asana.com/0/11984721910118/1204991209236659'>REVIEW / RELEASE</a> Asana project:"
	printf '%s' '<ul>'
	printf '%s' "<li>Set the title to <strong>macOS App Release ${marketing_version}</strong></li>"
	printf '%s' '<li>Copy the content below (between separators) and paste as the message body.</li>'
	printf '%s' '</ul>\n<hr>'
	
	printf '%s' '<h1>Release notes</h1>'
	printf '%s' "$release_notes"
	printf '%s' '\n'
	printf '%s' '<h2>This release includes:</h2>'

	construct_this_release_includes
	printf '%s' '\n'

	printf '%s' '<strong>Rollout</strong>\n'
	printf '%s' 'This is now rolling out to users. New users will receive this release immediately, '
	printf '%s' 'existing users will receive this gradually over the next few days. You can force an update now '
	printf '%s' 'by going to the DuckDuckGo menu in the menu bar and selecting "Check For Updates".'
	printf '%s' '<hr>'
	printf '%s' '</body>'
}

update_task_description() {
	local html_notes="$1"
	local escaped_html_notes=${html_notes//\"/\\\"}
	local request_payload="{\"data\":{\"html_notes\":\"${escaped_html_notes}\"}}"

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
		printf '%s' "Moving task $task_id to section $section_id ..."
		curl -fLSs "${asana_api_url}/sections/${section_id}/addTask" \
			-H 'Content-Type: application/json' \
			-H "Authorization: Bearer ${ASANA_ACCESS_TOKEN}" \
			--output /dev/null \
			-d "{\"data\": {\"task\": \"${task_id}\"}}"
		echo '✅'
	done
}

find_asana_release_tag() {
	local marketing_version="$1"
	local tag_name="macos-app-release-${marketing_version}"
	local tag_id

	tag_id="$(curl -fLSs "${asana_api_url}/tasks/${release_task_id}/tags?opt_fields=name" \
		-H "Authorization: Bearer ${ASANA_ACCESS_TOKEN}" \
		| jq -r ".data[] | select(.name==\"${tag_name}\").gid")"

	echo "$tag_id"
}

find_or_create_asana_release_tag() {
	local marketing_version="$1"
	local tag_name="macos-app-release-${marketing_version}"
	local tag_id

	tag_id="$(find_asana_release_tag "$marketing_version")"

	if [[ -z "$tag_id" ]]; then
		tag_id=$(curl -fLSs "${asana_api_url}/workspaces/${workspace_id}/tags?opt_fields=gid" \
			-H 'Content-Type: application/json' \
			-H "Authorization: Bearer ${ASANA_ACCESS_TOKEN}" \
			-d "{\"data\": {\"name\": \"${tag_name}\"}}" | jq -r .data.gid)
	fi

	echo "$tag_id"
}

tag_tasks() {
	local tag_id="$1"
	shift
	local task_ids=("$@")

	for task_id in "${task_ids[@]}"; do
		curl -fLSs "${asana_api_url}/tasks/${task_id}/addTag" \
			-H 'Content-Type: application/json' \
			-H "Authorization: Bearer ${ASANA_ACCESS_TOKEN}" \
			--output /dev/null \
			-d "{\"data\": {\"tag\": \"${tag_id}\"}}"
	done
}

fetch_tagged_tasks_ids() {
	local tag_id="$1"
	local url="${asana_api_url}/tags/${tag_id}/tasks?opt_fields=gid&limit=100"
	local response
	local tasks_list
	local task_ids=()

	while true; do
		response=$(curl -fLSs "$url" -H "Authorization: Bearer ${ASANA_ACCESS_TOKEN}")
		tasks_list="$(jq -r .data[].gid <<< "$response")"
		url="$(jq -r .next_page.uri <<< "$response")"

		while read -r line; do
			task_ids+=("$line")
		done <<< "$tasks_list"

		if [[ "$url" == "null" ]]; then
			break
		fi
	done

	echo "${task_ids[@]}"
}

fetch_incident_task_ids() {
	local url="${asana_api_url}/tasks/${incidents_parent_task_id}/subtasks?opt_fields=gid&limit=100"
	local response
	local tasks_list
	local task_ids=()

	while true; do
		response=$(curl -fLSs "$url" -H "Authorization: Bearer ${ASANA_ACCESS_TOKEN}")
		tasks_list="$(jq -r .data[].gid <<< "$response")"
		url="$(jq -r .next_page.uri <<< "$response")"

		while read -r line; do
			task_ids+=("$line")
		done <<< "$tasks_list"

		if [[ "$url" == "null" ]]; then
			break
		fi
	done

	echo "${task_ids[@]}"
}

complete_tasks() {
	local task_ids=("$@")

	# 1. Fetch incident task IDs (subtasks of the incidents umbrella task)
	local incident_task_ids
	read -ra incident_task_ids <<< "$(fetch_incident_task_ids)"

	for task_id in "${task_ids[@]}"; do
		if [[ "$task_id" == "$release_task_id" ]]; then
			continue
		fi

		# 2. Check if task is in Current Objectives project
		local is_in_current_objectives_project
		is_in_current_objectives_project="$(curl -fLSs "${asana_api_url}/tasks/${task_id}/projects?opt_fields=gid" \
			-H "Authorization: Bearer ${ASANA_ACCESS_TOKEN}" \
			| jq -r ".data[] | select(.gid == \"${current_objectives_project_id}\").gid")"

		# 3. If not in Current Objectives and not an incident task, mark as completed
		# shellcheck disable=SC2076
		if [[ -z "$is_in_current_objectives_project" ]] && ! [[ "${incident_task_ids[*]}" =~ "$task_id" ]]; then
			printf '%s' "Closing task $task_id ..."
			curl -X PUT -fLSs "${asana_api_url}/tasks/${task_id}" \
				-H "Authorization: Bearer ${ASANA_ACCESS_TOKEN}" \
				-H 'content-type: application/json' \
				--output /dev/null \
				-d '{"data": {"completed": true}}'
			echo '✅'
		else
			echo "Not closing task $task_id because it's a Current Objective or an incident task"
		fi
	done
}

handle_internal_release() {
	# 1. Fetch task URLs from git commit messages
	local last_release_tag
	last_release_tag="$(gh api /repos/duckduckgo/macos-browser/releases/latest --jq .tag_name)"

	local task_ids=()
	while read -r line; do
		local task_id
		task_id="$(get_task_id "$line")"
		if [[ -n "$task_id" ]]; then
			task_ids+=("$task_id")
		fi
	done <<< "$(find_task_urls_in_git_log "$last_release_tag")"

	# 2. Fetch current release notes from Asana release task.
	local release_notes
	release_notes="$(fetch_current_release_notes "${release_task_id}")"

	# 3. Construct new release task description
	local html_notes
	html_notes="$(construct_release_task_description)"

	# 4. Update release task description
	update_task_description "$html_notes"

	# 5. Move all tasks (including release task itself) to the validation section
	task_ids+=("${release_task_id}")
	move_tasks_to_section "$target_section_id" "${task_ids[@]}"

	# 6. Get the existing Asana tag for the release, or create a new one.
	local tag_id
	tag_id=$(find_or_create_asana_release_tag "$marketing_version")

	# 7. Tag all tasks with the release tag
	tag_tasks "$tag_id" "${task_ids[@]}"
}

handle_public_release() {
	local incidents_parent_task_id="${INCIDENTS_PARENT_TASK_ID:-${default_incidents_parent_task_id}}"
	local current_objectives_project_id="${CURRENT_OBJECTIVES_PROJECT_ID:-${default_current_objectives_project_id}}"

	# 1. Get the existing Asana tag for the release.
	local tag_id
	tag_id=$(find_asana_release_tag "$marketing_version")

	# 2. Fetch task IDs for the release tag.
	local task_ids
	read -ra task_ids <<< "$(fetch_tagged_tasks_ids "$tag_id")"

	# 3. Move all tasks to Done section.
	move_tasks_to_section "$target_section_id" "${task_ids[@]}"

	# 4. Complete tasks that don't require a post-mortem.
	complete_tasks "${task_ids[@]}"

	# 5. Fetch current release notes from Asana release task.
	local release_notes
	release_notes="$(fetch_current_release_notes "${release_task_id}")"

	# 6. Construct release announcement task description
	local html_notes
	html_notes="$(construct_release_announcement_task_description)"
	cat > "${announcement_task_contents_file}" <<< "${html_notes}"
}

get_tasks_in_last_internal_release() {
	# 1. Find last internal release tag (last internal release is the second one, because the first one is the release that's just created)
	local last_release_tag
	last_release_tag="$(gh api /repos/duckduckgo/macos-browser/releases?per_page=2 --jq .[1].tag_name)"

	# 2. Convert Asana task URLs from git commit messages to task IDs
	local task_ids=()
	while read -r line; do
		local task_id
		task_id="$(get_task_id "$line")"
		if [[ -n "$task_id" ]]; then
			task_ids+=("$task_id")
		fi
	done <<< "$(find_task_urls_in_git_log "$last_release_tag")"

	# 3. Construct a HTML list of task IDs
	local tasks_list
	tasks_list="$(construct_this_release_includes)"
	local escaped_tasks_list="${tasks_list//\"/\\\"}"
	echo "$escaped_tasks_list"
}

main() {
	local release_type="$1"
	local release_task_id="$2"
	local target_section_id="$3"
	local marketing_version="$4"

	case "$release_type" in
		internal)
			handle_internal_release
			;;
		public | hotfix)
			local announcement_task_contents_file="$5"
			handle_public_release
			;;
		list-tasks-in-last-internal-release)
			get_tasks_in_last_internal_release
			;;
		*)
			echo "Invalid release type: ${release_type}" >&2
			exit 1
			;;
	esac

}

main "$@"