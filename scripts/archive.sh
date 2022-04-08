#!/bin/bash

set -eo pipefail

print_usage_and_exit() {
    echo "Usage:"
    echo "  $ $0 <review|release>"
    echo
    echo "To clean keychain entries:"
    echo "  $ $0 clean-keychain"
    exit 1
}

clean_keychain() {
    while security delete-generic-password -s ddg-macos-app-archive-script >/dev/null 2>&1; do
        true
    done
    echo "Removed keychain entries used by the script."
    exit 0
}

set_up_environment() {
    CWD="$(dirname "$0")"
    XCPRETTY="xcpretty"
    WORKDIR="${PWD}/release"
    ARCHIVE="${WORKDIR}/DuckDuckGo.xcarchive"
    NOTARIZATION_ZIP_PATH="${WORKDIR}/DuckDuckGo-for-notarization.zip"
    NOTARIZATION_INFO_PLIST="${WORKDIR}/notarization-info.plist"
    NOTARIZATION_STATUS_INFO_PLIST="${WORKDIR}/notarization-status-info.plist"

    if [ $# -lt 1 ]; then
        print_usage_and_exit
    fi

    case $1 in
        review)
            APP_NAME="DuckDuckGo Review"
            SCHEME="Product Review Release"
            CONFIGURATION="Review"
            ;;
        release)
            APP_NAME="DuckDuckGo"
            SCHEME="DuckDuckGo Privacy Browser"
            CONFIGURATION="Release"
            ;;
        clean-keychain)
            clean_keychain
            ;;
        *)
            echo "Unknown build type '$1'"
            print_usage_and_exit
            ;;
    esac

    if [[ -z $CI ]]; then
        EXPORT_OPTIONS_PLIST="${CWD}/ExportOptions.plist"
    else
        EXPORT_OPTIONS_PLIST="${CWD}/ExportOptions_CI.plist"
        CONFIGURATION="CI_${CONFIGURATION}"
    fi

    APP_PATH="${WORKDIR}/${APP_NAME}.app"
}

user_has_password_in_keychain() {
    security find-generic-password \
        -s ddg-macos-app-archive-script \
        -a "$1" \
        >/dev/null 2>&1
}

retrieve_password_from_keychain() {
    security find-generic-password \
        -s ddg-macos-app-archive-script \
        -a "$1" \
        -w \
        2>&1
}

store_password_in_keychain() {
    security add-generic-password \
        -s ddg-macos-app-archive-script \
        -a "$1" \
        -w "$2"
}

get_developer_credentials() {
    DEVELOPER_APPLE_ID="${XCODE_DEVELOPER_APPLE_ID}"
    DEVELOPER_PASSWORD="${XCODE_DEVELOPER_PASSWORD}"

    if [[ -z "${DEVELOPER_APPLE_ID}" ]]; then

        while [[ -z "${DEVELOPER_APPLE_ID}" ]]; do
            echo "Please enter Apple ID that will be used for requesting notarization"
            echo "Set it in XCODE_DEVELOPER_APPLE_ID environment variable to not be asked again."
            echo
            read -rp "Apple ID: " DEVELOPER_APPLE_ID
            echo
        done

    else
        echo "Using ${DEVELOPER_APPLE_ID} Apple ID"
    fi

    if [[ -z "${DEVELOPER_PASSWORD}" ]]; then

        if user_has_password_in_keychain "${DEVELOPER_APPLE_ID}"; then
            echo "Found Apple ID password in the keychain"
            DEVELOPER_PASSWORD=$(retrieve_password_from_keychain "${DEVELOPER_APPLE_ID}")
        else
            while [[ -z "${DEVELOPER_PASSWORD}" ]]; do
                echo "Set password in XCODE_DEVELOPER_PASSWORD environment variable to not be asked for password."
                echo "Currently only application-specific password is supported (create one at https://appleid.apple.com)."
                echo
                read -srp "Password for ${DEVELOPER_APPLE_ID}: " DEVELOPER_PASSWORD
                echo
            done

            store_password_in_keychain "${DEVELOPER_APPLE_ID}" "${DEVELOPER_PASSWORD}"
        fi
    fi
}

clean_working_directory() {
    rm -rf "${WORKDIR}"
    mkdir -p "${WORKDIR}"
}

check_xcpretty() {
    if ! command -v xcpretty &> /dev/null; then
        echo
        echo "xcpretty not found - not prettifying Xcode logs. You can install it using 'gem install xcpretty'."
        echo
        XCPRETTY='tee'
    fi
}

prepare_export_options() {
    if [[ -z $CI ]]; then
        :
    else
        SIGNING_CERTIFICATE=$(security find-certificate -Z -c "Developer ID Application:" | grep "SHA-1" | awk 'NF { print $NF }')
        TEAM_ID=$(security find-certificate -c "Developer ID Application:" | grep "alis" | awk 'NF { print $NF }' | tr -d \(\)\")

        plutil -replace signingCertificate -string "${SIGNING_CERTIFICATE}" "${EXPORT_OPTIONS_PLIST}"
        plutil -replace teamID -string "${TEAM_ID}" "${EXPORT_OPTIONS_PLIST}"
    fi
}

archive_and_export() {
    echo
    echo "Building and archiving the app ..."
    echo
    
    xcrun xcodebuild archive \
        -scheme "${SCHEME}" \
        -configuration "${CONFIGURATION}" \
        -archivePath "${WORKDIR}/DuckDuckGo" \
        | ${XCPRETTY}

    echo
    echo "Exporting archive ..."
    echo

    prepare_export_options

    xcrun xcodebuild -exportArchive \
        -archivePath "${ARCHIVE}" \
        -exportPath "${WORKDIR}" \
        -exportOptionsPlist "${EXPORT_OPTIONS_PLIST}" \
        -configuration "${CONFIGURATION}" \
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
    /usr/libexec/PlistBuddy -c "Print :notarization-upload:RequestUUID" "${NOTARIZATION_INFO_PLIST}"
}

get_notarization_status() {
    /usr/libexec/PlistBuddy -c "Print :notarization-info:Status" "${NOTARIZATION_STATUS_INFO_PLIST}"
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

compress_app_and_dsym() {
    echo
    echo "Compressing app and dSYMs ..."
    echo
    ditto -c -k --keepParent "${APP_PATH}" "${WORKDIR}/DuckDuckGo.zip"
    ditto -c -k --keepParent "${ARCHIVE}/dSYMs/${APP_NAME}.app.dSYM" "${WORKDIR}/${APP_NAME}.app.dSYM.zip"
}

main() {
    set_up_environment "$@"
    get_developer_credentials
    clean_working_directory
    check_xcpretty
    archive_and_export
    upload_for_notarization
    wait_for_notarization
    staple_notarized_app
    compress_app_and_dsym

    echo
    echo "Notarized app ready at ${APP_PATH}"
    echo "Compressed app ready at ${WORKDIR}/DuckDuckGo.zip"
    echo "Compressed debug symbols ready at ${WORKDIR}/${APP_NAME}.app.dSYM.zip"

    if [[ -z $CI ]]; then
        open "${WORKDIR}"
    fi
}

main "$@"
