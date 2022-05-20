#!/bin/bash

set -eo pipefail

cwd="$(dirname "${BASH_SOURCE[0]}")"
developer_apple_id_keychain_identifier="developer-apple-id"
source "${cwd}/helpers/common.sh"

read_command_line_arguments() {
	if (( $# < 1 )); then
		print_usage_and_exit
	fi

	case "$1" in
		review)
			app_name="DuckDuckGo Review"
			scheme="Product Review Release"
			configuration="Review"
			;;
		release)
			app_name="DuckDuckGo"
			scheme="DuckDuckGo Privacy Browser"
			configuration="Release"
			;;
		clear-keychain)
			clear_keychain
			;;
		*)
			echo "Unknown build type '$1'"
			print_usage_and_exit
			;;
	esac

	shift 1

	while getopts 'a:dsv:' OPTION; do
		case "${OPTION}" in
			a)
				asana_task_url="${OPTARG}"
				if [[ ${create_dmg} -ne 1 ]]; then
					create_dmg_preflight
				fi
				;;
			d)
				create_dmg_preflight
				;;
			s)
				# Use silent_output function to redirect all output to /dev/null
				filter_output='silent_output'
				;;
			v)
				override_version="${OPTARG}"
				;;
			*)
				print_usage_and_exit
				;;
		esac
	done

	shift $((OPTIND-1))
}

print_usage_and_exit() {
	cat <<- EOF
	Usage:
	  $ $(basename "$0") <review|release> [-a <asana_task_url>] [-d] [-s] [-v <version>]

	Options:
	 -a <asana_task_url>  Update Asana task after building the app (implies -d)
	 -d                   Create a DMG image alongside the zipped app and dSYMs
	 -s                   Skip xcodebuild output in logs
	 -v <version>         Override app version with <version> (does not update Xcode project)

	To clear keychain entries:
	  $ $(basename "$0") clear-keychain

	EOF

	die "Build type not specified"
}

create_dmg_preflight() {
	if ! command -v create-dmg &> /dev/null; then
		cat <<- EOF
		create-dmg is required to create DMG images. Install it with:
		  $ brew install create-dmg

		EOF
		die
	fi

	echo "Will create DMG image after building the app."
	create_dmg=1
}

set_up_environment() {
	workdir="${PWD}/release"
	archive="${workdir}/DuckDuckGo.xcarchive"
	notarization_info_plist="${workdir}/notarization-info.plist"

	if [[ -z $CI ]]; then
		export_options_plist="${cwd}/assets/ExportOptions.plist"
	else
		export_options_plist="${cwd}/assets/ExportOptions_CI.plist"
		configuration="CI_${configuration}"
	fi

	if [[ -n "${override_version}" ]]; then
		app_version="${override_version}"
	else
		source "${cwd}/helpers/version.sh"
		app_version=$(get_app_version "${scheme}")
	fi

	app_path="${workdir}/${app_name}.app"
	dsym_path="${archive}/dSYMs"

	output_app_zip_path="${workdir}/DuckDuckGo-${app_version}.zip"
	output_dsym_zip_path="${workdir}/DuckDuckGo-${app_version}-dSYM.zip"
}

get_developer_credentials() {
	developer_apple_id="${XCODE_DEVELOPER_APPLE_ID}"
	developer_password="${XCODE_DEVELOPER_PASSWORD}"

	if [[ -z "${developer_apple_id}" ]]; then

		if is_item_in_keychain "${developer_apple_id_keychain_identifier}"; then
			developer_apple_id=$(retrieve_item_from_keychain "${developer_apple_id_keychain_identifier}")
			echo "Using Apple ID found in the keychain: ${developer_apple_id}"
		else
			while [[ -z "${developer_apple_id}" ]]; do
				cat <<- EOF
				Please enter Apple ID that will be used for requesting notarization.
				It will be stored in keychain and you won't be asked for it the next time.
				Alternatively set the Apple ID in XCODE_DEVELOPER_APPLE_ID environment variable
				to skip storing in keychain.

				EOF
				read -rp "Apple ID: " developer_apple_id
				echo
			done

			store_item_in_keychain "${developer_apple_id_keychain_identifier}" "${developer_apple_id}"
		fi
	else
		echo "Using ${developer_apple_id} Apple ID"
	fi

	if [[ -z "${developer_password}" ]]; then

		if is_item_in_keychain "${developer_apple_id}"; then
			developer_password=$(retrieve_item_from_keychain "${developer_apple_id}")
			echo "Found Apple ID password in the keychain"
		else
			while [[ -z "${developer_password}" ]]; do
				cat <<- EOF
				Enter your Apple ID application-specific password (create one at https://appleid.apple.com).
				It will be stored in keychain and you won't be asked for it the next time.
				Alternatively set the password in XCODE_DEVELOPER_PASSWORD environment variable 
				to skip storing in keychain.
				
				EOF
				read -srp "Password for ${developer_apple_id}: " developer_password
				echo
			done

			store_item_in_keychain "${developer_apple_id}" "${developer_password}"
		fi
	fi
}

clear_working_directory() {
	rm -rf "${workdir}"
	mkdir -p "${workdir}"
}

prepare_export_options_in_ci() {
	if [[ -n $CI ]]; then
		local signing_certificate
		local team_id
		
		signing_certificate=$(security find-certificate -Z -c "Developer ID Application:" | grep "SHA-1" | awk 'NF { print $NF }')
		team_id=$(security find-certificate -c "Developer ID Application:" | grep "alis" | awk 'NF { print $NF }' | tr -d \(\)\")

		plutil -replace signingCertificate -string "${signing_certificate}" "${export_options_plist}"
		plutil -replace teamID -string "${team_id}" "${export_options_plist}"
	fi
}

check_xcpretty() {
	if ! command -v xcpretty &> /dev/null; then
		echo
		echo "xcpretty not found - not prettifying Xcode logs. You can install it using 'gem install xcpretty'."
		echo
		xcpretty='tee'
	else
		xcpretty='xcpretty'
	fi
}

archive_and_export() {
	local xcpretty
	check_xcpretty

	echo
	echo "Building and archiving the app (version ${app_version}) ..."
	echo
	
	${filter_output} xcrun xcodebuild archive \
		-scheme "${scheme}" \
		-configuration "${configuration}" \
		-archivePath "${archive}" \
		CURRENT_PROJECT_VERSION="${app_version}" \
		MARKETING_VERSION="${app_version}" \
		2>&1 \
		| ${xcpretty}

	echo
	echo "Exporting archive ..."
	echo

	prepare_export_options_in_ci

	${filter_output} xcrun xcodebuild -exportArchive \
		-archivePath "${archive}" \
		-exportPath "${workdir}" \
		-exportOptionsPlist "${export_options_plist}" \
		-configuration "${configuration}" \
		2>&1 \
		| ${xcpretty}
}

altool_upload() {
	xcrun altool --notarize-app \
		--primary-bundle-id "com.duckduckgo.macos.browser" \
		-u "${developer_apple_id}" \
		-p "${developer_password}" \
		-f "${notarization_zip_path}" \
		--output-format xml \
		2>/dev/null \
		> "${notarization_info_plist}"
}

upload_for_notarization() {
	local notarization_zip_path="${workdir}/DuckDuckGo-for-notarization.zip"

	ditto -c -k --keepParent "${app_path}" "${notarization_zip_path}"

	local retries=3
	while true; do
		echo
		printf '%s' "Uploading app for notarization ... "

		if altool_upload; then
			echo "Done"
			break
		else
			echo "Failed to upload, retrying ..."
			retries=$(( retries - 1 ))
		fi

		if (( retries == 0 )); then
			die "Maximum number of retries reached."
		fi
	done
	echo

	rm -rf "${notarization_zip_path}"
}

get_notarization_info() {
	/usr/libexec/PlistBuddy -c "Print :notarization-upload:RequestUUID" "${notarization_info_plist}"
}

get_notarization_status() {
	/usr/libexec/PlistBuddy -c "Print :notarization-info:Status" "${notarization_status_info_plist}"
}

altool_check_notarization_status () {
	xcrun altool --notarization-info "$(get_notarization_info)" \
		-u "${developer_apple_id}" \
		-p "${developer_password}" \
		--output-format xml \
		2>/dev/null \
		> "${notarization_status_info_plist}"
}

wait_for_notarization() {
	local notarization_status_info_plist="${workdir}/notarization-status-info.plist"

	echo "Checking notarization status ..."
	while true; do
		if altool_check_notarization_status; then
			if [[ "$(get_notarization_status)" != "in progress" ]]; then
				echo "Notarization complete"
				break
			else
				echo "Still in progress, rechecking in 60 seconds ..."
				sleep 60
			fi
		else
			echo "Failed to fetch notarization info, rechecking in 10 seconds ..."
			sleep 10
		fi
	done
}

staple_notarized_app() {
	${filter_output} xcrun stapler staple "${app_path}"
}

compress_app_and_dsym() {
	echo
	echo "Compressing app and dSYMs ..."
	echo
	ditto -c -k --keepParent "${app_path}" "${output_app_zip_path}"
	ditto -c -k --keepParent "${dsym_path}" "${output_dsym_zip_path}"
}

create_dmg() {
	echo
	echo "Creating DMG image ..."
	echo
	local dmg_dir="${workdir}/dmg"
	local dmg_background="${cwd}/assets/dmg-background.png"
	dmg_output_path="${workdir}/duckduckgo-${app_version}.dmg"

	rm -rf "${dmg_dir}" "${dmg_output_path}"
	mkdir -p "${dmg_dir}"
	cp -R "${app_path}" "${dmg_dir}"
	${filter_output} create-dmg --volname "${app_name}" \
		--icon "${app_name}.app" 140 160 \
		--background "${dmg_background}" \
		--window-size 600 400 \
		--icon-size 120 \
		--app-drop-link 430 160 "${dmg_output_path}" \
		"${dmg_dir}"
}

export_app_version_to_environment() {
	if [[ -n "${GITHUB_ENV}" ]]; then
		echo "app_version=${app_version}" >> "${GITHUB_ENV}"
	fi
}

main() {
	# Load keychain-related functions first, because `clear-keychain`
	# is required when parsing command-line arguments.
	source "${cwd}/helpers/keychain.sh"
	read_command_line_arguments "$@"
	
	# Load Asana-related functions. This calls `_asana_preflight` which
	# will check for Asana access token if needed (if asana task was passed to the script).
	source "${cwd}/helpers/asana.sh"

	set_up_environment "$@"
	get_developer_credentials
	clear_working_directory
	archive_and_export
	upload_for_notarization
	wait_for_notarization
	staple_notarized_app
	compress_app_and_dsym

	if [[ ${create_dmg} ]]; then
		create_dmg

		if [[ ${asana_task_id} ]]; then
			asana_update_task "${dmg_output_path}" "${output_dsym_zip_path}"
		fi
	fi

	echo
	echo "Notarized app ready at ${app_path}"
	if [[ ${create_dmg} ]]; then
		echo "App DMG image ready at ${dmg_output_path}"
	fi
	echo "Compressed app ready at ${output_app_zip_path}"
	echo "Compressed debug symbols ready at ${output_dsym_zip_path}"

	if [[ -n $CI ]]; then
		export_app_version_to_environment
	else
		open "${workdir}"
	fi
}

main "$@"
