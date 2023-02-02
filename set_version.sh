#!/bin/bash

version_number="$1"

if [[ -z "${version_number}" ]]; then
   echo 'Usage: ./set_version.sh VERSION_NUMBER'
   echo 'Example: ./set_version.sh 0.28.6'
   echo "Current version: $(cut -d ' ' -f 3 <Configuration/Version.xcconfig)"
   exit 1
fi

current_build_number=$(cut -d ' ' -f 3 <Configuration/AppStoreBuildNumber.xcconfig)
next_build_number=$(( current_build_number + 1 ))

printf 'APP_VERSION = %s\n' "${version_number}" | tee Configuration/Version.xcconfig
printf 'CURRENT_PROJECT_VERSION = %s\n' "${next_build_number}" | tee Configuration/AppStoreBuildNumber.xcconfig
