#!/bin/bash
#
# This script extracts release notes or included tasks from Asana release task description.
#
# Usage:
#   cat release_task_description.txt | ./extract_release_notes.sh [-t]
#

start_marker="release notes"
pp_marker="for privacy pro subscribers"
end_marker="this release includes:"
is_capturing=0
has_content=0

# Capture raw included tasks' URLs instead of release notes
list_tasks=$([[ "$1" == "-t" ]] && echo 1 || echo 0)

if [[ $list_tasks -eq 1 ]]; then
    start_marker="this release includes:"
    pp_marker=
    end_marker=
fi

while read -r line
do
    # Lowercase each line to compare with markers
    lowercase_line=$(tr '[:upper:]' '[:lower:]' <<< "$line")

    if [[ "$lowercase_line" == "$start_marker" ]]; then
        # Only start capturing here
        is_capturing=1
        if [[ $list_tasks -eq 0 ]]; then
            # Add HTML header and start the list
            echo "<h3 style=\"font-size:14px\">What's new</h3>"
            echo "<ul>"
        fi
    elif [[ -n "$pp_marker" && "$lowercase_line" == "$pp_marker" ]]; then
        # If we've reached the PP marker, end the list and start the PP list
        echo "</ul>"
        echo "<h3 style=\"font-size:14px\">For Privacy Pro subscribers</h3>"
        echo "<ul>"
    elif [[ -n "$end_marker" && "$lowercase_line" == "$end_marker" ]]; then
        # End the list on end marker
        echo "</ul>"
        exit 0
    elif [[ $is_capturing -eq 1 && -n "$line" ]]; then
        has_content=1
        if [[ $list_tasks -eq 1 ]]; then
            echo "$line"
        else
            # Add each line as a list item and convert URLs to clickable links
            echo "<li>$(sed -E 's|(https://[^ ]*)|<a href=\1>\1</a>|' <<< "$line")</li>"
        fi
    fi
done

if [[ $has_content -eq 0 ]]; then
    exit 1
fi

exit 0
