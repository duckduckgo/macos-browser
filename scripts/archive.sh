#!/bin/bash

set -eo pipefail

if ! [[ $common_sh ]]; then
	cwd="$(dirname "${BASH_SOURCE[0]}")"
	source "${cwd}/helpers/common.sh"
	execute_from_tmp "${BASH_SOURCE[0]}" "$@"
fi

developer_apple_id_keychain_identifier="developer-apple-id"

print_usage_and_exit() {
	local reason=$1

	cat <<- EOF
	Usage:
	  $ $(basename "$0") <review|release|dbp> [-a <asana_task_url>] [-d] [-s] [-r] [-v <version>]

	Options:
	 -a <asana_task_url>  Update Asana task after building the app (implies -d)
	 -d                   Create a DMG image alongside the zipped app and dSYMs
	 -h                   Print this message
	 -r                   Show raw output (don't use xcpretty or xcbeautify)
	 -s                   Skip xcodebuild output in logs
	 -v <version>         Override app version with <version> (does not update Xcode project)

	This script is only meant for building notarized apps. For making App Store builds, use fastlane.

	To clear keychain entries:
	  $ $(basename "$0") clear-keychain

	EOF

	die "${reason}"
}

read_command_line_arguments() {
	if (( $# < 1 )); then
		print_usage_and_exit "Build type not specified"
	fi

	case "$1" in
		review)
			app_name="DuckDuckGo Review"
			scheme="macOS Browser Review"
			configuration="Review"
			;;
		release)
			app_name="DuckDuckGo"
			scheme="macOS Browser"
			configuration="Release"
			;;
		clear-keychain)
			clear_keychain
			;;
		*)
			print_usage_and_exit "Unknown build type '$1'"
			;;
	esac

	shift 1

	while getopts 'a:dhrsv:' OPTION; do
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
			h)
				print_usage_and_exit
				;;
			r)
				disable_log_formatting=1
				;;
			s)
				# Use silent_output function to redirect all output to /dev/null
				filter_output='silent_output'
				;;
			v)
				override_version="${OPTARG}"
				;;
			*)
				print_usage_and_exit "Unknown option '${OPTION}'"
				;;
		esac
	done

	shift $((OPTIND-1))
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
	team_id=$(security find-certificate -c "Developer ID Application: Duck" | grep "alis" | awk 'NF { print $NF }' | tr -d \(\)\")
	export_options_plist="${cwd}/assets/ExportOptions.plist"

	source "${cwd}/helpers/version.sh"
	if [[ -n "${override_version}" ]]; then
		app_version="${override_version}"
	else
		app_version=$(get_app_version "${scheme}")
	fi
	build_number=$(get_build_number "${scheme}")
	version_identifier="${app_version}.${build_number}"

	app_path="${workdir}/${app_name}.app"
	dsym_path="${archive}/dSYMs"

	output_app_zip_path="${workdir}/DuckDuckGo-${version_identifier}.zip"
	output_dsym_zip_path="${workdir}/DuckDuckGo-${version_identifier}-dSYM.zip"
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

prepare_export_options_plist() {
	local signing_certificate
	signing_certificate=$(security find-certificate -Z -c "Developer ID Application:" | grep "SHA-1" | awk 'NF { print $NF }')

	plutil -replace signingCertificate -string "${signing_certificate}" "${export_options_plist}"
	plutil -replace teamID -string "${team_id}" "${export_options_plist}"
}

setup_log_formatter() {
	if [[ ${disable_log_formatting} ]]; then
		echo
		echo "Log formatting disabled - not prettifying Xcode logs."
		echo
		log_formatter='tee'
	elif command -v xcbeautify &> /dev/null; then
		log_formatter='xcbeautify'
	elif command -v xcpretty &> /dev/null; then
		log_formatter='xcpretty'
	else
		echo
		echo "xcbeautify and xcpretty not found - not prettifying Xcode logs. You can install xcbeautify using 'brew install xcbeautify'."
		echo
		log_formatter='tee'
	fi
}

archive_and_export() {
	local log_formatter
	setup_log_formatter

	echo "Building and archiving the app version ${app_version} (${build_number}) ..."

	local derived_data="${workdir}/DerivedData"
	rm -rf "${derived_data}"
	
	${filter_output} xcrun xcodebuild archive \
		-scheme "${scheme}" \
		-configuration "${configuration}" \
		-archivePath "${archive}" \
		-derivedDataPath "${derived_data}" \
		-skipPackagePluginValidation -skipMacroValidation \
		MARKETING_VERSION="${app_version}" \
		CURRENT_PROJECT_VERSION="${build_number}" \
		RELEASE_PRODUCT_NAME_OVERRIDE=DuckDuckGo \
		2>&1 \
		| ${log_formatter}

	echo "Exporting archive ..."

	prepare_export_options_plist

	${filter_output} xcrun xcodebuild -exportArchive \
		-archivePath "${archive}" \
		-exportPath "${workdir}" \
		-exportOptionsPlist "${export_options_plist}" \
		-configuration "${configuration}" \
		-skipPackagePluginValidation -skipMacroValidation \
		2>&1 \
		| ${log_formatter}
}

notarize() {
	local notarization_zip_path="${workdir}/DuckDuckGo-for-notarization.zip"

	echo "Uploading app for notarization ..."

	ditto -c -k --keepParent "${app_path}" "${notarization_zip_path}"
	if [[ -n $CI ]]; then
		${filter_output} xcrun notarytool submit \
			--key "${APPLE_API_KEY_PATH}" \
			--key-id "${APPLE_API_KEY_ID}" \
			--issuer "${APPLE_API_KEY_ISSUER}" \
			--wait \
			"${notarization_zip_path}"
	else
		${filter_output} xcrun notarytool submit \
			--apple-id "${developer_apple_id}" \
			--password "${developer_password}" \
			--team-id "${team_id}" \
			--wait \
			"${notarization_zip_path}"
	fi
}

staple_notarized_app() {
	${filter_output} xcrun stapler staple "${app_path}"
}

compress_app_and_dsym() {
	echo "Compressing app and dSYMs ..."

	ditto -c -k --keepParent "${app_path}" "${output_app_zip_path}"
	ditto -c -k --keepParent "${dsym_path}" "${output_dsym_zip_path}"
}

create_dmg() {
	echo "Creating DMG image ..."

	local dmg_dir="${workdir}/dmg"
	local dmg_background="${cwd}/assets/dmg-background.png"
	dmg_output_path="${workdir}/duckduckgo-${version_identifier}.dmg"

	rm -rf "${dmg_dir}" "${dmg_output_path}"
	mkdir -p "${dmg_dir}"
	cp -R "${app_path}" "${dmg_dir}"
	# Using APFS filesystem as per https://github.com/actions/runner-images/issues/7522#issuecomment-2299918092
	${filter_output} create-dmg --volname "${app_name}" \
		--filesystem APFS \
		--icon "${app_name}.app" 140 160 \
		--background "${dmg_background}" \
		--window-size 600 400 \
		--icon-size 120 \
		--app-drop-link 430 160 "${dmg_output_path}" \
		"${dmg_dir}"
}

export_app_version_to_environment() {
	if [[ -n "${GITHUB_ENV}" ]]; then
		echo "app-version=${version_identifier}" >> "${GITHUB_ENV}"
		echo "app-name=${app_name}" >> "${GITHUB_ENV}"
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

	# CI uses Apple API Key to communicate with notarization service
	# and expects relevant environment variables to be defined.
	# For running script locally, we're currently relying on Apple ID
	# and application-specific password.
	if [[ -z $CI ]]; then
		get_developer_credentials
	fi

	clear_working_directory
	archive_and_export
	notarize
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
