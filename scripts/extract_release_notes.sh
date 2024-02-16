#!/bin/bash
#
# This script extracts release notes from Asana release task description.
#
# Usage:
#   cat release_task_description.txt | ./extract_release_notes.sh
#

notes_start="release notes:"
notes_end="this release includes:"
is_release_notes=0
has_release_notes=0

while read -r line
do
    if [[ $(tr '[:upper:]' '[:lower:]' <<< "$line") == "$notes_start" ]]; then
        is_release_notes=1
    elif [[ $(tr '[:upper:]' '[:lower:]' <<< "$line") == "$notes_end" ]]; then
        exit 0
    elif [[ $is_release_notes -eq 1 && -n "$line" ]]; then
        has_release_notes=1
        echo "$line"
    fi
done

if [[ $has_release_notes -eq 0 ]]; then
    exit 1
fi

exit 0
