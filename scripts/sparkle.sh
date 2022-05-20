#!/bin/bash

set -eo pipefail

cwd="$(dirname "${BASH_SOURCE[0]}")"
source "${cwd}/helpers/common.sh"
cdn_dir="${PWD}/cdn"

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
	basic_auth="$(random_string):$(random_string)"
	ngrok http --log stdout --basic-auth "${basic_auth}"  "file://${cdn_dir}" >/dev/null &
	ngrok_pid=$!

	sleep 1
	server_url=$(
		curl -s http://localhost:4040/api/tunnels \
		| jq '.tunnels[0].public_url' \
		| tr -d '"' \
		| sed -E "s~(https://)~\1${basic_auth}@~"
	)

	echo "ngrok running on ${server_url} (pid ${ngrok_pid})"
	trap clean_up SIGINT
}

update_info_plist() {
	plutil -replace SUFeedURL -string "${server_url}/appcast.xml" DuckDuckGo/Info.plist
}

build_app_and_copy_dmg() {
	local version="$1"

	echo "Building app version ${version}. This can take a couple of minutes ..."

	"${cwd}/archive.sh" review -d -s -v "${version}"
	cp -f "${PWD}/release/duckduckgo-${version}.dmg" "${cdn_dir}"

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
	check_ngrok
	kill_existing_ngrok_processes
	prepare_fake_cdn_directory
	start_ngrok
	update_info_plist

	source "${cwd}/helpers/version.sh"
	base_app_version="$(get_app_version "Product Review Release")"
	build_app_and_copy_dmg "${base_app_version}"

	bumped_version="$(bump_version "${base_app_version}")"
	build_app_and_copy_dmg "${bumped_version}"

	echo "Generating appcast.xml ..."
	generate_appcast "${cdn_dir}"

	wait_for_sigint
}

main
