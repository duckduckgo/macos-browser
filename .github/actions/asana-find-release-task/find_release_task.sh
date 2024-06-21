#!/bin/bash
#
# This script is used to find the current release task.
#

set -e

asana_app_url="https://app.asana.com/0/0"
asana_api_url="https://app.asana.com/api/1.0"
default_release_and_maintenance_section_id="1202202395298964"

find_latest_marketing_version() {
	local latest_tag
	latest_tag="$(gh api /repos/duckduckgo/macos-browser/releases?per_page=1 --jq .[0].tag_name)"
	echo "${latest_tag%-*}" # remove everything after - (including -) i.e. x.y.z-N becomes x.y.z
}

# Find the release task in 'Release & Maintenance' section of the 'macOS App Development' Asana project.
# - If there is no release task, return nothing.
# - If there is an active (incomplete) hotfix task, return nothing.
find_release_task() {
	local version="$1"
	local task_name="macOS App Release ${version}"
	local hotfix_task_name_prefix="macOS App Hotfix Release"
	local section_id="${RELEASE_AND_MAINTENANCE_SECTION_ID:-$default_release_and_maintenance_section_id}"

	# `completed_since=now` returns only incomplete tasks
	local url="${asana_api_url}/sections/${section_id}/tasks?opt_fields=name,created_at&limit=100&completed_since=now"
	local response
	local hotfix_task_id
	local created_at

	# go through all tasks in the section (there may be multiple requests in case there are more than 100 tasks in the section)
	# repeat until no more pages (next_page.uri is null)
	while true; do
		response="$(curl -fLSs "$url" -H "Authorization: Bearer ${ASANA_ACCESS_TOKEN}")"
		# echo "$response"

		# find task id only if not found yet
		if [[ -z "$release_task_id" || "$release_task_id" == "null" ]]; then
			release_task_id="$(jq -r ".data[] | select(.name == \"${task_name}\").gid" <<< "$response")"
			created_at="$(jq -r ".data[] | select(.name == \"${task_name}\").created_at" <<< "$response")"

			# Only consider release tasks created in the last 5 days.
			# - We don't want to bump internal release automatically for release tasks that are open for more than a week.
			# - The automatic check is only done Tuesday-Friday. If the release task is still open next Tuesday, it's unexpected,
			#   and likely something went wrong.
			if [[ -n "$created_at" && "$created_at" != "null" ]]; then
				created_at_timestamp="$(TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%S." "$created_at" +%s)"
				four_days_ago="$(date -j -v-5d +%s)"
				if [[ "$created_at_timestamp" -le "$four_days_ago" ]]; then
					echo "::error::Found release task: ${asana_app_url}/${release_task_id} but it's older than 5 days, skipping."
					exit 1
				fi
			fi
		fi

		# find hotfix task id only if not found yet
		if [[ -z "$hotfix_task_id" || "$hotfix_task_id" == "null" ]]; then
			hotfix_task_id="$(jq -r ".data[] | select(.name | startswith(\"${hotfix_task_name_prefix}\")).gid" <<< "$response")"
		fi

		url="$(jq -r .next_page.uri <<< "$response")"

		# break on last page
		if [[ "$url" == "null" ]]; then
			break
		fi
	done

	if [[ -n "$hotfix_task_id" && "$hotfix_task_id" != "null" ]]; then
		echo "::error::Found active hotfix task: ${asana_app_url}/${hotfix_task_id}"
		exit 1
	fi
}

main() {
	local latest_marketing_version
	local release_task_id
	latest_marketing_version="$(find_latest_marketing_version)"
	echo "Latest marketing version: ${latest_marketing_version}"
	find_release_task "$latest_marketing_version"

	if [[ -n "$release_task_id" && "$release_task_id" != "null" ]]; then
		echo "Found ${latest_marketing_version} release task: ${asana_app_url}/${release_task_id}/f"
		# shellcheck disable=SC2129
		echo "release-branch=release/${latest_marketing_version}" >> "$GITHUB_OUTPUT"
		echo "task-id=${release_task_id}" >> "$GITHUB_OUTPUT"
		echo "task-url=${asana_app_url}/${release_task_id}/f" >> "$GITHUB_OUTPUT"
	else
		echo "::warning::No release task found for version: ${latest_marketing_version}"
	fi
}

main "%@"
