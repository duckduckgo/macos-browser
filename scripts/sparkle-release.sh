#!/bin/bash

set -eo pipefail

cwd="$(dirname "${BASH_SOURCE[0]}")"
source "${cwd}/helpers/common.sh"

action=
workdir="${HOME}/Developer/sparkle-updates"
appcast_file_name="appcast2.xml"

print_usage_and_exit() {
	local reason=$1

	cat <<- EOF
	Usage:
	  $ $(basename "$0") <download|generate|upload> [-d <directory>] [-h]

	Options:
	 -d		Use directory specified by <directory> (defaults to ~/Developer/sparkle-updates)
	 -h		Print this message

	EOF

	die "${reason}"
}

read_command_line_arguments() {
	if (( $# < 1 )); then
		print_usage_and_exit "Action not specified"
	fi

	action="$1"
	shift 1

	while getopts 'd:h' OPTION; do
		case "${OPTION}" in
			d)
				workdir="${OPTARG}"
				;;
			h)
				print_usage_and_exit
				;;
			*)
				print_usage_and_exit "Unknown option '${OPTION}'"
				;;
		esac
	done

	shift $((OPTIND-1))
}

download_file() {
	local url="$1"
	local file_name="${2:-$(basename "$url")}"
	local tmp_file_path
	tmp_file_path="$(mktemp)"
	local file_path="${workdir}/${file_name}"
	printf '%s' "Downloading ${url} to ${file_path} ... "
	curl -sSLf -o "$tmp_file_path" "$url"
	mv -f "$tmp_file_path" "$file_path"
	echo '✅'
}

download_appcast_and_dmgs() {
	mkdir -p "$workdir"
	local appcast_path="${workdir}/${appcast_file_name}"
	download_file "https://staticcdn.duckduckgo.com/macos-desktop-browser/${appcast_file_name}"
	local dmgs
	# shellcheck disable=SC2207
	dmgs=( $(xpath -q -e 'rss/channel/item/enclosure/@url' "$appcast_path" | awk -F'"' '{print $2}') )
	for dmg in "${dmgs[@]}"; do
		download_file "$dmg"
	done
}

regenerate_appcast() {
	local workdir="$1"
	local appcast_path="${workdir}/${appcast_file_name}"
	local tmp_appcast_path
	local old_appcast_backup
	tmp_appcast_path="$(mktemp)"
	old_appcast_backup="$(mktemp)"
	cp -f "$appcast_path" "$old_appcast_backup"
	echo "Regenerating ${appcast_file_name} and binary deltas. It may take a few moments ... "
	generate_appcast "$workdir"

	cat <<- EOF

	Diff between current and new appcast files:
	==============================
	$(git diff --color=always "$old_appcast_backup" "$appcast_path")
	==============================
	EOF
	rm -f "$old_appcast_backup"
	
	printf '%s' "Removing old items to keep only two most recent ones ... "

	# Extract the header and opening tags
	head -n 4 "$appcast_path" > "$tmp_appcast_path"
	# Extract the first two <item> elements
	local prefix='        ' # Fix padding
	xpath -q -e '/rss/channel/item[position() <= 2]' -p "$prefix" "$appcast_path" | sed -e 's/&lt;/</g' >> "$tmp_appcast_path"
	# Add the closing tags
	tail -n 2 "$appcast_path" >> "$tmp_appcast_path"

	mv -f "$tmp_appcast_path" "$appcast_path"
	echo '✅'
	echo "Appcast file has been successfully regenerated at ${appcast_path}."
	echo "Update it with release notes and phased rollout tag."
}

upload_appcast_and_binaries() {
	local appcast_url="https://staticcdn.duckduckgo.com/macos-desktop-browser/${appcast_file_name}"
	# shellcheck disable=SC2207
	local existing_dmgs=( $(xpath -q -e 'rss/channel/item/enclosure/@url' <<< "$(curl -sSLf "$appcast_url")" | awk -F'"' '{print $2;}' | xargs basename -a) )
	for file in "${workdir}"/*; do
		# shellcheck disable=SC2076
		if ! [[ ${existing_dmgs[*]} =~ "$(basename "$file")" ]]; then
			aws --profile ddg-macos s3 cp "$file" "s3://ddg-staticcdn/macos-desktop-browser/$(basename "$file")" --acl public-read
		fi
		# TODO: Upload the latest release as duckduckgo.dmg
	done
}

main() {
	read_command_line_arguments "$@"

	printf '%s\n' "Using directory at ${workdir}"

	case "$action" in
		download)
			download_appcast_and_dmgs
			;;
		generate)
			regenerate_appcast "$workdir"
			;;
		upload)
			upload_appcast_and_binaries "$workdir"
			;;
		*)
			print_usage_and_exit "Unknown action '$action'"
			;;
	esac
}

main "$@"