#!/bin/bash

if [[ -n "$CI" ]]; then
    echo "Skipping SwiftLint run in CI"
    exit 0
fi

# Add brew into PATH
if [[ -f /opt/homebrew/bin/brew ]]; then
   eval "$(/opt/homebrew/bin/brew shellenv)"
fi

run_swiftlint_for_modified_files () {
    TEST_FILES=""
    CODE_FILES=""

    # collect staged and unstaged files and replace spaces in filenames with #001
    for FILE_NAME in $({ git diff --name-only & git diff --cached --name-only; }  | tr ' ' '\001' | tr '\n ' ' ')
    do
        # collect .swift files separately for Unit Tests and Code Files
        if [[ "${FILE_NAME##*.}" == "swift" ]]; then
            # check if file exists (replacing  back #001 with space)
            if [ -f "$(echo "${FILE_NAME}"  | tr '\001' ' ')" ]; then
                if [[ "$FILE_NAME" == *"Tests/"* ]]; then
                    TEST_FILES+=" \"${FILE_NAME}\""
                else
                    CODE_FILES+=" \"${FILE_NAME}\""
                fi
            fi
        fi
    done

    if [ -n "${CODE_FILES}" ]; then
        # replace  back #001 with space and feed to swiftlint
        echo "${CODE_FILES}"  | tr '\001' ' ' | xargs swiftlint lint
    fi
    if [ -n "${TEST_FILES}" ]; then
        echo "${TEST_FILES}" | tr '\001' ' ' | xargs swiftlint lint --config .swiftlint.tests.yml
    fi
}

if which swiftlint >/dev/null; then
    if [ "$CONFIGURATION" = "Release" ]; then
        swiftlint lint --strict
        if [ $? -ne 0 ]; then
            echo "error: SwiftLint validation failed."
            exit 1
        fi
    else
        run_swiftlint_for_modified_files
    fi
else
    echo "error: SwiftLint not installed. Install using \`brew install swiftlint\`"
    exit 1
fi
