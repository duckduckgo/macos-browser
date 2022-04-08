#!/bin/bash

set -e

CWD="$(dirname $0)"
WORKDIR="${PWD}/release"
ARCHIVE="${WORKDIR}/DuckDuckGo"
APP_PATH="${ARCHIVE} Review.app"
ZIP_PATH="${ARCHIVE} Review.zip"
NOTARIZATION_INFO_PLIST="${WORKDIR}/notarization-info.plist"
NOTARIZATION_STATUS_INFO_PLIST="${WORKDIR}/notarization-status-info.plist"

SCHEME="Product Review Release"

get_developer_credentials () {
    DEVELOPER_APPLE_ID="${XCODE_DEVELOPER_APPLE_ID}"
    DEVELOPER_PASSWORD="${XCODE_DEVELOPER_PASSWORD}"
    if [[ -z "${DEVELOPER_APPLE_ID}" ]]; then
        read -p 'Apple ID: ' DEVELOPER_APPLE_ID
    fi
    if [[ -z "${DEVELOPER_PASSWORD}" ]]; then
        read -sp 'Password: ' DEVELOPER_PASSWORD
        echo
    fi
}

clean_working_directory () {
    rm -rf "${WORKDIR}"
    mkdir -p "${WORKDIR}"
}

archive_and_export () {
    xcrun xcodebuild archive \
        -scheme "${SCHEME}" \
        -archivePath "${WORKDIR}/DuckDuckGo" \
        | xcpretty

    xcrun xcodebuild -exportArchive \
        -archivePath "${ARCHIVE}.xcarchive" \
        -exportPath "${WORKDIR}" \
        -exportOptionsPlist "${CWD}/ExportOptions.plist" \
        -configuration Release \
        | xcpretty
}

upload_for_notarization() {
    ditto -c -k --keepParent "${APP_PATH}" "${ZIP_PATH}"

    retries=3
    while true
    do
        printf '%s' "Uploading app for notarization ... "

        xcrun altool --notarize-app \
            --primary-bundle-id "com.duckduckgo.macos.browser.review" \
            -u "${DEVELOPER_APPLE_ID}" \
            -p "${DEVELOPER_PASSWORD}" \
            -f "${ZIP_PATH}" \
            --output-format xml \
            2>/dev/null \
            > "${NOTARIZATION_INFO_PLIST}"

        if [[ $? -eq 0 ]]; then
            echo "Done"
            break
        elif [[ $? -ne 0 ]]; then
            echo "Failed to upload, retrying ..."
            retries=$((retries-1))
        fi

        if [[ $retries -eq 0 ]]; then
            echo "Maximum number of retries reached."
            exit 1
        fi
    done
}

get_notarization_info () {
    echo $(/usr/libexec/PlistBuddy -c "Print :notarization-upload:RequestUUID" "${NOTARIZATION_INFO_PLIST}")
}

get_notarization_status () {
    echo $(/usr/libexec/PlistBuddy -c "Print :notarization-info:Status" "${NOTARIZATION_STATUS_INFO_PLIST}")
}

wait_for_notarization() {
    echo "Checking notarization status ..."
    while true
    do
        xcrun altool --notarization-info "$(get_notarization_info)" \
            -u "${DEVELOPER_APPLE_ID}" \
            -p "${DEVELOPER_PASSWORD}" \
            --output-format xml \
            2>/dev/null \
            > "${NOTARIZATION_STATUS_INFO_PLIST}"
        if [[ $? -ne 0 ]]; then
            echo "Failed to fetch notarization info, rechecking in 10 seconds ..."
            sleep 10
        elif [[ "$(get_notarization_status)" != "in progress" ]]; then
            echo "Notarization complete"
            break
        else
            echo "Still in progress, rechecking in 60 seconds ..."
            sleep 60
        fi
    done
}

staple_notarized_app() {
    xcrun stapler staple "${APP_PATH}"
}

main () {
    get_developer_credentials
    clean_working_directory
    archive_and_export
    upload_for_notarization
    wait_for_notarization
    staple_notarized_app

    echo "Notarized app ready at ${APP_PATH}"

    if [[ -z $CI ]]; then
        open $(dirname ${APP_PATH})
    fi
}

main
