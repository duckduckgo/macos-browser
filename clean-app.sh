#!/bin/bash

delete_data() {
    bundle_id="$1"

    printf '%s' "Deleting data for ${bundle_id}..."

    if defaults read "${bundle_id}" &>/dev/null; then
        defaults delete "${bundle_id}"
    fi

    data_path="${HOME}/Library/Containers/${bundle_id}/Data"
    if [ -d "${data_path}" ]; then
        rm -r "${data_path}" || { echo "Failed to delete ${data_path}"; exit 1; }
        echo " Done."
    else
        printf '\nNothing to do for %s\n' "${data_path}"
    fi
}

bundle_id=
config_id=

case "$1" in
    debug)
        bundle_id="com.duckduckgo.macos.browser.debug"
        config_ids="*com.duckduckgo.macos.browser.app-configuration.debug"
        netp_bundle_ids_glob="*com.duckduckgo.macos.browser.network-protection*debug"
        ;;
    review)
        bundle_id="com.duckduckgo.macos.browser.review"
        config_ids="*com.duckduckgo.macos.browser.app-configuration.review"
        netp_bundle_ids_glob="*com.duckduckgo.macos.browser.network-protection*review"
        ;;
    debug-appstore)
        bundle_id="com.duckduckgo.mobile.ios.debug"
        config_ids="*com.duckduckgo.mobile.ios.app-configuration.debug"
        ;;
    review-appstore)
        bundle_id="com.duckduckgo.mobile.ios.review"
        config_ids="*com.duckduckgo.mobile.ios.app-configuration.review"
        ;;
    *)
        echo "usage: clean-app debug|review|debug-appstore|review-appstore"
        exit 1
        ;;
esac

delete_data "${bundle_id}"

# shellcheck disable=SC2046
read -r -a config_bundle_ids <<< $(
    find "${HOME}/Library/Group Containers/" \
        -type d \
        -maxdepth 1 \
        -name "${config_ids}" \
        -exec basename {} \;
)
for config_id in "${config_bundle_ids[@]}"; do
    path="${HOME}/Library/Group Containers/${config_id}"
    printf '%s' "Deleting data at ${path}... "
    if [ -d "${path}" ]; then
        rm -r "${path}" || { echo "Failed to delete ${path}"; exit 1; }
        echo "Done."
    else
        printf '\nNothing to do for %s\n' "${path}"
    fi

done

if [[ -n "${netp_bundle_ids_glob}" ]]; then
    # shellcheck disable=SC2046
    read -r -a netp_bundle_ids <<< $(
        find "${HOME}/Library/Containers/" \
            -type d \
            -maxdepth 1 \
            -name "${netp_bundle_ids_glob}" \
            -exec basename {} \;
    )
    for netp_bundle_id in "${netp_bundle_ids[@]}"; do
        delete_data "${netp_bundle_id}"
    done
fi
