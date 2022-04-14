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
    while security delete-generic-password -s "${KEYCHAIN_SERVICE_NAME}" >/dev/null 2>&1; do
        true
    done
    echo "Removed keychain entries used by the script."
    exit 0
}

set_up_environment() {
    KEYCHAIN_SERVICE_NAME="ddg-macos-app-archive-script"
    WORKDIR="${PWD}/release"
    ARCHIVE="${WORKDIR}/DuckDuckGo.xcarchive"
    NOTARIZATION_INFO_PLIST="${WORKDIR}/notarization-info.plist"

    if (( $# < 1 )); then
        print_usage_and_exit
    fi

    case "$1" in
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

    local cwd
    cwd="$(dirname "$0")"
    if [[ -z $CI ]]; then
        EXPORT_OPTIONS_PLIST="${cwd}/ExportOptions.plist"
    else
        EXPORT_OPTIONS_PLIST="${cwd}/ExportOptions_CI.plist"
        CONFIGURATION="CI_${CONFIGURATION}"
    fi

    APP_PATH="${WORKDIR}/${APP_NAME}.app"
    DSYM_PATH="${ARCHIVE}/dSYMs/${APP_NAME}.app.dSYM"

    OUTPUT_APP_ZIP_PATH="${WORKDIR}/DuckDuckGo.zip"
    OUTPUT_DSYM_ZIP_PATH="${WORKDIR}/${APP_NAME}.app.dSYM.zip"
}

user_has_password_in_keychain() {
    local account="$1"
    security find-generic-password \
        -s "${KEYCHAIN_SERVICE_NAME}" \
        -a "${account}" \
        >/dev/null 2>&1
}

retrieve_password_from_keychain() {
    local account="$1"
    security find-generic-password \
        -s "${KEYCHAIN_SERVICE_NAME}" \
        -a "${account}" \
        -w \
        2>&1
}

store_password_in_keychain() {
    local account="$1"
    local password="$2"
    security add-generic-password \
        -s "${KEYCHAIN_SERVICE_NAME}" \
        -a "${account}" \
        -w "${password}"
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

prepare_export_options_in_ci() {
    if [[ -n $CI ]]; then
        local signing_certificate
        local team_id
        
        signing_certificate=$(security find-certificate -Z -c "Developer ID Application:" | grep "SHA-1" | awk 'NF { print $NF }')
        team_id=$(security find-certificate -c "Developer ID Application:" | grep "alis" | awk 'NF { print $NF }' | tr -d \(\)\")

        plutil -replace signingCertificate -string "${signing_certificate}" "${EXPORT_OPTIONS_PLIST}"
        plutil -replace teamID -string "${team_id}" "${EXPORT_OPTIONS_PLIST}"
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
    echo "Building and archiving the app ..."
    echo
    
    xcrun xcodebuild archive \
        -scheme "${SCHEME}" \
        -configuration "${CONFIGURATION}" \
        -archivePath "${ARCHIVE}" \
        | ${xcpretty}

    echo
    echo "Exporting archive ..."
    echo

    prepare_export_options_in_ci

    xcrun xcodebuild -exportArchive \
        -archivePath "${ARCHIVE}" \
        -exportPath "${WORKDIR}" \
        -exportOptionsPlist "${EXPORT_OPTIONS_PLIST}" \
        -configuration "${CONFIGURATION}" \
        | ${xcpretty}
}

altool_upload() {
    xcrun altool --notarize-app \
        --primary-bundle-id "com.duckduckgo.macos.browser" \
        -u "${DEVELOPER_APPLE_ID}" \
        -p "${DEVELOPER_PASSWORD}" \
        -f "${notarization_zip_path}" \
        --output-format xml \
        2>/dev/null \
        > "${NOTARIZATION_INFO_PLIST}"
}

upload_for_notarization() {
    local notarization_zip_path="${WORKDIR}/DuckDuckGo-for-notarization.zip"

    ditto -c -k --keepParent "${APP_PATH}" "${notarization_zip_path}"

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
    /usr/libexec/PlistBuddy -c "Print :notarization-info:Status" "${notarization_status_info_plist}"
}

altool_check_notarization_status () {
    xcrun altool --notarization-info "$(get_notarization_info)" \
        -u "${DEVELOPER_APPLE_ID}" \
        -p "${DEVELOPER_PASSWORD}" \
        --output-format xml \
        2>/dev/null \
        > "${notarization_status_info_plist}"
}

wait_for_notarization() {
    local notarization_status_info_plist="${WORKDIR}/notarization-status-info.plist"

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
    ditto -c -k --keepParent "${APP_PATH}" "${OUTPUT_APP_ZIP_PATH}"
    ditto -c -k --keepParent "${DSYM_PATH}" "${OUTPUT_DSYM_ZIP_PATH}"
}

main() {
    set_up_environment "$@"
    get_developer_credentials
    clean_working_directory
    archive_and_export
    upload_for_notarization
    wait_for_notarization
    staple_notarized_app
    compress_app_and_dsym

    echo
    echo "Notarized app ready at ${APP_PATH}"
    echo "Compressed app ready at ${OUTPUT_APP_ZIP_PATH}"
    echo "Compressed debug symbols ready at ${OUTPUT_DSYM_ZIP_PATH}"

    if [[ -z $CI ]]; then
        open "${WORKDIR}"
    fi
}

main "$@"
