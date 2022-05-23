#!/bin/bash

set -eo pipefail

if ! [[ $common_sh ]]; then
	cwd="$(dirname "${BASH_SOURCE[0]}")"
	source "${cwd}/helpers/common.sh"
	execute_from_tmp "${BASH_SOURCE[0]}" "$@"
fi

cdn_dir="${PWD}/cdn"

print_usage_and_exit() {
	local reason=$1

	cat <<- EOF
	Usage:
	  $ $(basename "$0") [-i]

	Options:
	 -h  Print this message
	 -i  Interactive mode: stop the script to allow switching branches and/or making
	     changes to the code before building the app each time.

	EOF

	die "${reason}"
}

read_command_line_arguments() {
	while getopts 'hi' OPTION; do
		case "${OPTION}" in
			h)
				print_usage_and_exit
				;;
			i)
				interactive=1
				;;
			*)
				print_usage_and_exit "Unknown option '${OPTION}'"
				;;
		esac
	done

	shift $((OPTIND-1))
}

check_ngrok() {
	if ! command -v ngrok &> /dev/null; then
		cat <<- EOF
		ngrok is required to serve local directories online.
		Install it with:
		  $ brew install ngrok

		You will also need to create an account at https://dashboard.ngrok.com/signup
		and install authtoken (available from your dashboard: https://dashboard.ngrok.com/get-started/your-authtoken)

		EOF
		die "ngrok not installed"
	fi
}

kill_existing_ngrok_processes() {
	local ngrok_pids
	read -ra ngrok_pids <<< "$(pgrep ngrok)"

	if [[ -n "${ngrok_pids[*]}" ]]; then
		printf '%s' 'Killing existing ngrok processes ... '

		if kill "${ngrok_pids[*]}"; then
			echo "Done"
		else
			echo "Failed to kill ngrok. Please stop any ngrok processes and restart the script."
			exit 1
		fi
	fi
}

clean_up() {
	kill_existing_ngrok_processes
	exit 0
}

prepare_fake_cdn_directory() {
	rm -rf "${cdn_dir}"
	mkdir -p "${cdn_dir}"
}

start_ngrok() {
	local basic_auth
	# shellcheck disable=2119
	basic_auth="$(random_string):$(random_string)"
	echo "Starting ngrok ..."
	ngrok http --log stdout --basic-auth "${basic_auth}" "file://${cdn_dir}" >/dev/null &
	ngrok_pid=$!

	# Wait until tunnel is created
	while true; do
		sleep 1
		server_url=$(
			curl -s http://localhost:4040/api/tunnels \
			| jq '.tunnels[0].public_url' \
			| tr -d '"' \
			| sed -E "s~(https://)~\1${basic_auth}@~"
		)

		if [[ ${server_url} != "null" ]]; then
			break
		fi
	done

	echo "Running ngrok on ${server_url} (pid ${ngrok_pid})"
	trap clean_up SIGINT
}

get_feed_url() {
	plutil -extract SUFeedURL raw DuckDuckGo/Info.plist
}

update_feed_url() {
	local value="$1"
	plutil -replace SUFeedURL -string "${value}" DuckDuckGo/Info.plist
}

build_app_and_copy_dmg() {
	local version="$1"

	echo "Building app version ${version}. This can take a couple of minutes ..."

	feed_url="$(get_feed_url)"
	update_feed_url "${server_url}/appcast.xml"
	
	"${cwd}/archive.sh" review -d -s -v "${version}"
	cp -f "${PWD}/release/duckduckgo-${version}.dmg" "${cdn_dir}"

	update_feed_url "${feed_url}"

	echo "Done building app version ${version}."
}

wait_for_sigint() {
	cat <<- EOF

	Temporary file server (pid ${ngrok_pid}) is running on:
	${server_url}

	Directory contents:
	$(find "${cdn_dir}" -depth 1 | awk -F/ '{ print $NF; }' | sort)

	When you're done testing, press CTRL+C to stop ngrok tunnel.

	EOF

	read -r -d '' _
}

main() {
	read_command_line_arguments "$@"
	check_ngrok
	kill_existing_ngrok_processes
	prepare_fake_cdn_directory
	start_ngrok

	if [[ ${interactive} ]]; then
		cat <<- EOF

		Prepare the code for building source version (pre-update).
		Don't bother updating SUFeedURL in the Info.plist file or app version in project settings
		as they will be set to correct values automatically. Press Return key when ready.
		EOF

		read -r
	fi

	source "${cwd}/helpers/version.sh"
	base_app_version="$(get_app_version "Product Review Release")"
	build_app_and_copy_dmg "${base_app_version}"


	if [[ ${interactive} ]]; then
		cat <<- EOF

		Prepare the code for building target version (that Sparkle would offer to update to).
		Don't bother updating SUFeedURL in the Info.plist file or app version in project settings
		as they will be set to correct values automatically. Press Return key when ready.
		EOF

		read -r
	fi

	bumped_version="$(bump_version "${base_app_version}")"
	build_app_and_copy_dmg "${bumped_version}"

	echo "Generating appcast.xml ..."
	generate_appcast "${cdn_dir}"

	wait_for_sigint
}

main "$@"
