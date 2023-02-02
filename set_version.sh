#!/bin/bash

version_number="$1"
build_number="${2:-0}"

if [[ -z "${version_number}" ]]; then
   echo 'Usage: ./set_version.sh VERSION_NUMBER [BUILD_NUMBER=0]'
   echo 'Example: ./set_version.sh 0.28.6 0'
   echo "Current version: $(cut -d ' ' -f 3 <Configuration/Version.xcconfig)"
   exit 1
fi

printf 'APP_VERSION = %s' "${version_number}" > Configuration/Version.xcconfig
printf 'CURRENT_PROJECT_VERSION = %s' "${build_number}" > Configuration/AppStoreBuildNumber.xcconfig
