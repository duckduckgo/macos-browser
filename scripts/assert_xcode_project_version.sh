#!/bin/bash

# Change directory where the script is located
cd "$(dirname "$0")"
# Required Xcode Project Version
REQUIRED_XCODE_PROJECT_VERSION="54"
# Path to the project.pbxproj file
PBXPROJECT="project.pbxproj"
PROJECT_PATH="../DuckDuckGo-macOS.xcodeproj"
PBXPROJECT_PATH="${PROJECT_PATH}/${PBXPROJECT}"

# Extract the objectVersion from the .pbxproj file
objectVersion=$(grep -m 1 "objectVersion" "$PBXPROJECT_PATH" | awk -F' = ' '{print $2}' | tr -d ';')

# Check if objectVersion is not equal to 54
if [[ "$objectVersion" != "$REQUIRED_XCODE_PROJECT_VERSION" ]]; then
  echo "error: The Project .pbxproj version $objectVersion is not compatible with Xcode 15. We run e2e tests on macOS versions that use Xcode 15. Xcode project version ${REQUIRED_XCODE_PROJECT_VERSION} is required."
  exit 1
else
  echo "The Project version is compatible with Xcode 15."
fi
