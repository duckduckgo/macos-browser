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

while read -r line
do
	# Lowercase each line to compare with markers
	lowercase_line="$(lowercase "$line")"

	if [[ "$lowercase_line" == "$start_marker" ]]; then
		# Only start capturing here
		is_capturing=1
		if [[ "$output" == "asana" ]]; then
			printf '%s' '<ul>'
		elif [[ "$output" == "html" ]]; then
			# Add HTML header and start the list
			echo "<h3 style=\"font-size:14px\">What's new</h3>"
			echo "<ul>"
		fi
	elif [[ -n "$pp_marker" && "$lowercase_line" =~ $pp_marker ]]; then
		is_capturing_pp=1
		if [[ "$output" == "asana" ]]; then
			pp_notes="$(printf '%s' '</ul>')"
			pp_notes+="$(printf '%s' '<h2>For Privacy Pro subscribers</h2>')"
			pp_notes+="$(printf '%s' '<ul>')"
		elif [[ "$output" == "html" ]]; then
			# If we've reached the PP marker, end the list and start the PP list\
			# redirect to pp_notes variable
			pp_notes="</ul>\\n"
			pp_notes+="<h3 style=\"font-size:14px\">For Privacy Pro subscribers</h3>\\n"
			pp_notes+="<ul>\\n"
		else
			pp_notes="$line\\n"
		fi
	elif [[ -n "$end_marker" && "$lowercase_line" == "$end_marker" ]]; then
		# If we've reached the end marker, end the PP list and start the end list
		# shellcheck disable=SC2076
		if [[ -n "$pp_notes" && ! "$(lowercase "$pp_notes")" =~ "$placeholder" ]]; then
			if [[ "$output" == "asana" ]]; then
				printf '%s' "$pp_notes"
			else
				echo -ne "$pp_notes"
			fi
		fi
		# End the list on end marker
		if [[ "$output" == "asana" ]]; then
			printf '%s' '</ul>'
		elif [[ "$output" == "html" ]]; then
			echo "</ul>"
		fi
		exit 0
	elif [[ $is_capturing -eq 1 && -n "$line" ]]; then
		has_content=1
		if [[ "$output" == "asana" ]]; then
			escaped_line=$(html_escape "$line")
			if [[ $is_capturing_pp -eq 1 ]]; then
				pp_notes+="<li>$(make_links "$escaped_line")</li>"
			else
				printf '%s' "<li>$(make_links "$escaped_line")</li>"
			fi
		elif [[ "$output" == "html" ]]; then
			# Add each line as a list item and convert URLs to clickable links
			escaped_line=$(html_escape "$line")
			if [[ $is_capturing_pp -eq 1 ]]; then
				pp_notes+="<li>$(make_links "$escaped_line")</li>\\n"
			else
				echo "<li>$(make_links "$escaped_line")</li>"
			fi
		else
			if [[ $is_capturing_pp -eq 1 ]]; then
				pp_notes+="$line\\n"
			else
				echo "$line"
			fi
		fi
	fi
done

if [[ $has_content -eq 0 ]]; then
	exit 1
fi

exit 0
