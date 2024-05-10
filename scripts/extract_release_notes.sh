#!/bin/bash
#
# This script extracts release notes or included tasks from Asana release task description.
#
# Usage:
#   cat release_task_description.txt | ./extract_release_notes.sh [-t]
#

start_marker="release notes"
pp_marker="^for privacy pro subscribers:?$"
end_marker="this release includes:"
placeholder="add release notes here"
is_capturing=0
is_capturing_pp=0
has_content=0
notes=
pp_notes=

output="html"

case "$1" in
	-a)
		# Generate Asana rich text output
		output="asana"
		;;
	-r)
		# Generate raw output instead of HTML
		output="raw"
		;;
	-t)
		# Capture raw included tasks' URLs instead of release notes
		output="tasks"
		start_marker="this release includes:"
		pp_marker=
		end_marker=
		;;
	*)
		;;
esac

html_escape() {
	local input="$1"
	sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' <<< "$input"
}

make_links() {
	local input="$1"
	sed -E 's|(https://[^ ]*)|<a href="\1">\1</a>|' <<< "$input"
}

lowercase() {
	local input="$1"
	tr '[:upper:]' '[:lower:]' <<< "$input"
}

print_and_exit() {
	echo -ne "$notes"
	exit 0
}

add_to_notes() {
	notes+="$1"
	if [[ "$output" != "asana" ]]; then
		notes+="\\n"
	fi
}

add_to_pp_notes() {
	pp_notes+="$1"
	if [[ "$output" != "asana" ]]; then
		pp_notes+="\\n"
	fi
}

add_release_note() {
	local release_note="$1"
	local processed_release_note=
	if [[ "$output" == "raw" || "$output" == "tasks" ]]; then
		processed_release_note="$release_note"
	else
		processed_release_note="<li>$(make_links "$(html_escape "$release_note")")</li>"
	fi
	if [[ $is_capturing_pp -eq 1 ]]; then
		add_to_pp_notes "$processed_release_note"
	else
		add_to_notes "$processed_release_note"
	fi
}

while read -r line
do
	# Lowercase each line to compare with markers
	lowercase_line="$(lowercase "$line")"

	if [[ "$lowercase_line" == "$start_marker" ]]; then
		# Only start capturing here
		is_capturing=1
		if [[ "$output" == "asana" ]]; then
			add_to_notes "<ul>"
		elif [[ "$output" == "html" ]]; then
			# Add HTML header and start the list
			add_to_notes "<h3 style=\"font-size:14px\">What's new</h3>"
			add_to_notes "<ul>"
		fi
	elif [[ -n "$pp_marker" && "$lowercase_line" =~ $pp_marker ]]; then
		is_capturing_pp=1
		if [[ "$output" == "asana" ]]; then
			add_to_pp_notes "</ul><h2>For Privacy Pro subscribers</h2><ul>"
		elif [[ "$output" == "html" ]]; then
			# If we've reached the PP marker, end the list and start the PP list
			add_to_pp_notes "</ul>"
			add_to_pp_notes "<h3 style=\"font-size:14px\">For Privacy Pro subscribers</h3>"
			add_to_pp_notes "<ul>"
		else
			add_to_pp_notes "$line"
		fi
	elif [[ -n "$end_marker" && "$lowercase_line" == "$end_marker" ]]; then
		# If we've reached the end marker, check if PP notes are present and not a placeholder, and add them verbatim to notes
		# shellcheck disable=SC2076
		if [[ -n "$pp_notes" && ! "$(lowercase "$pp_notes")" =~ "$placeholder" ]]; then
			notes+="$pp_notes" # never add extra newline here (that's why we don't use `add_to_notes`)
		fi
		if [[ "$output" != "raw" ]]; then
			# End the list on end marker
			add_to_notes "</ul>"
		fi
		# Print output and exit
		print_and_exit
	elif [[ $is_capturing -eq 1 && -n "$line" ]]; then
		has_content=1
		add_release_note "$line"
	fi
done

if [[ $has_content -eq 0 ]]; then
	exit 1
fi

print_and_exit
