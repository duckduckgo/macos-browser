#!/bin/bash

set -o pipefail

version_number="$1"
build_number_file="Configuration/AppStoreBuildNumber.xcconfig"
version_file="Configuration/Version.xcconfig"

if [[ -z "${version_number}" ]]; then
	echo 'Usage: ./set_version.sh VERSION_NUMBER'
	echo 'Example: ./set_version.sh 1.2.3'
	echo "Current version: $(cut -d ' ' -f 3 < "${version_file}")"
	exit 1
fi

if ! command -v gh &> /dev/null; then
	cat <<- EOF
	GH CLI is required to update Asana tasks. Install it with:
		$ brew install gh

	Follow setup instructions at https://app.asana.com/0/0/1203791243007683/f.

	EOF
	exit 1
fi

git restore "${build_number_file}"
current_local_build_number=$(cut -d ' ' -f 3 <Configuration/AppStoreBuildNumber.xcconfig)
current_build_number=$(gh variable list | grep CURRENT_PROJECT_VERSION | awk '{ print $2 }')

exit_code=$?
if [[ $exit_code -ne 0 ]]; then
	cat <<- EOF
	Failed to get current build number from GitHub Actions
	Verify that you have the correct permissions to access the repository

	Make sure you followed setup instructions for GH CLI at https://app.asana.com/0/0/1203791243007683/f.

	EOF
	exit $exit_code
fi

if [ "$current_local_build_number" -gt "$current_build_number" ]; then
	if [[ -n "$CI" ]]; then
		ans="y"
	else
		echo "Local build number (${current_local_build_number}) is greater than stored in GitHub Actions (${current_build_number})."
		printf '%s' "Do you want to use local build number? [y/n] "

		read -rsn1 ans
		echo
	fi

	if [[ "$ans" == "y" ]]; then
		next_build_number=$current_local_build_number
	else
		next_build_number=$(( current_build_number + 1 ))
	fi
else
	next_build_number=$(( current_build_number + 1 ))
fi

echo "Next build number: ${next_build_number}"
echo "Storing next build number in GitHub Actions variable"

if ! gh variable set CURRENT_PROJECT_VERSION -b "${next_build_number}"; then
	cat <<- EOF

	🚨 Failed to set CURRENT_PROJECT_VERSION variable in GitHub Actions.
	Please update it manually at https://github.com/duckduckgo/macos-browser/settings/variables/actions.

	EOF
fi

echo ""
printf 'MARKETING_VERSION = %s\n' "${version_number}" | tee "${version_file}"
printf 'CURRENT_PROJECT_VERSION = %s\n' "${next_build_number}" | tee "${build_number_file}"
