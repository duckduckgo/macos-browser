#!/bin/bash
#
# This script extracts release notes or included tasks from Asana release task description.
#
# Usage:
#   cat release_task_description.txt | ./extract_release_notes.sh [-t]
#

start_marker="release notes"
end_marker="this release includes:"
is_capturing=0
has_content=0

if [[ "$1" == "-t" ]]; then
    # capture included tasks instead of release notes
    start_marker="this release includes:"
    end_marker=
fi

while read -r line
do
    if [[ $(tr '[:upper:]' '[:lower:]' <<< "$line") == "$start_marker" ]]; then
        is_capturing=1
    elif [[ -n "$end_marker" && $(tr '[:upper:]' '[:lower:]' <<< "$line") == "$end_marker" ]]; then
        exit 0
    elif [[ $is_capturing -eq 1 && -n "$line" ]]; then
        has_content=1
        echo "$line"
    fi
done

if [[ $has_content -eq 0 ]]; then
    exit 1
fi

exit 0
