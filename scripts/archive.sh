#!/bin/bash

set -eo pipefail

print_usage_and_exit() {
    echo "usage: $0 <review|release>"
    exit 1
}

set_up_environment() {
    if [ $# -lt 1 ]; then
        print_usage_and_exit
    fi

    case $1 in
        review)
            APP_NAME="DuckDuckGo Review"
            SCHEME="Product Review Release"
            ;;
        release)
            APP_NAME="DuckDuckGo"
            SCHEME="DuckDuckGo Privacy Browser"
            ;;
        *)
            echo "Unknown build type '$1'"
            print_usage_and_exit
            ;;
    esac

    CWD="$(dirname $0)"
    XCPRETTY="xcpretty"
    WORKDIR="${PWD}/release"
    ARCHIVE="${WORKDIR}/DuckDuckGo.xcarchive"
    APP_PATH="${WORKDIR}/${APP_NAME}.app"
    NOTARIZATION_ZIP_PATH="${WORKDIR}/DuckDuckGo-for-notarization.zip"
    NOTARIZATION_INFO_PLIST="${WORKDIR}/notarization-info.plist"
    NOTARIZATION_STATUS_INFO_PLIST="${WORKDIR}/notarization-status-info.plist"
}

get_developer_credentials() {
    DEVELOPER_APPLE_ID="${XCODE_DEVELOPER_APPLE_ID}"
    DEVELOPER_PASSWORD="${XCODE_DEVELOPER_PASSWORD}"
    if [[ -z "${DEVELOPER_APPLE_ID}" ]]; then
        echo "Please enter Apple ID that will be used for requesting notarization"
        echo "Set it in XCODE_DEVELOPER_APPLE_ID environment variable to not be asked again."
        read -p "Apple ID: " DEVELOPER_APPLE_ID
    else
        echo "Using ${DEVELOPER_APPLE_ID} Apple ID"
    fi
    while [[ -z "${DEVELOPER_PASSWORD}" ]]; do
        echo "Set password in XCODE_DEVELOPER_PASSWORD environment variable to not be asked for password."
        read -sp "Password for ${DEVELOPER_APPLE_ID}: " DEVELOPER_PASSWORD
        echo
    done
}

clean_working_directory() {
    rm -rf "${WORKDIR}"
    mkdir -p "${WORKDIR}"
}

check_xcpretty() {
    if ! command -v xcpretty &> /dev/null; then
        echo
        echo 'xcpretty not found - not prettifying Xcode logs. You can install it using `gem install xcpretty`.'
        echo
        XCPRETTY='tee'
    fi
}

archive_and_export() {
    echo
    echo "Building and archiving the app ..."
    echo

    xcrun xcodebuild archive \
        -scheme "${SCHEME}" \
        -archivePath "${WORKDIR}/DuckDuckGo" \
        | ${XCPRETTY}

    echo
    echo "Exporting archive ..."
    echo

    xcrun xcodebuild -exportArchive \
        -archivePath "${ARCHIVE}" \
        -exportPath "${WORKDIR}" \
        -exportOptionsPlist "${CWD}/ExportOptions.plist" \
        -configuration Release \
        | ${XCPRETTY}
}

altool_upload() {
    xcrun altool --notarize-app \
        --primary-bundle-id "com.duckduckgo.macos.browser" \
        -u "${DEVELOPER_APPLE_ID}" \
        -p "${DEVELOPER_PASSWORD}" \
        -f "${NOTARIZATION_ZIP_PATH}" \
        --output-format xml \
        2>/dev/null \
        > "${NOTARIZATION_INFO_PLIST}"
}

upload_for_notarization() {
    ditto -c -k --keepParent "${APP_PATH}" "${NOTARIZATION_ZIP_PATH}"

    retries=3
    while true; do
        echo
        printf '%s' "Uploading app for notarization ... "

        if altool_upload; then
            echo "Done"
            break
        else
            echo "Failed to upload, retrying ..."
            retries=$((retries-1))
        fi

        if [[ $retries -eq 0 ]]; then
            echo "Maximum number of retries reached."
            exit 1
        fi
    done
    echo
}

get_notarization_info() {
    echo $(/usr/libexec/PlistBuddy -c "Print :notarization-upload:RequestUUID" "${NOTARIZATION_INFO_PLIST}")
}

get_notarization_status() {
    echo $(/usr/libexec/PlistBuddy -c "Print :notarization-info:Status" "${NOTARIZATION_STATUS_INFO_PLIST}")
}

altool_check_notarization_status () {
    xcrun altool --notarization-info "$(get_notarization_info)" \
        -u "${DEVELOPER_APPLE_ID}" \
        -p "${DEVELOPER_PASSWORD}" \
        --output-format xml \
        2>/dev/null \
        > "${NOTARIZATION_STATUS_INFO_PLIST}"
}

wait_for_notarization() {
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
    xcrun stapler staple "${APP_PATH}"
}

compress_app() {
    pushd "${WORKDIR}"
    rm -rf DuckDuckGo.zip
    zip -r9 DuckDuckGo.zip "$(basename "${APP_PATH}")"
    popd
}

main() {
    set_up_environment $@
    get_developer_credentials
    clean_working_directory
    check_xcpretty
    archive_and_export
    upload_for_notarization
    wait_for_notarization
    staple_notarized_app
    compress_app

    echo
    echo "Notarized app ready at ${APP_PATH}"
    echo "Compressed app ready at ${WORKDIR}/DuckDuckGo.zip"

    if [[ -z $CI ]]; then
        open "${WORKDIR}"
    fi
}

main $@
