#!/bin/sh

# Get the directory where the script is stored
script_dir=$(dirname "$(readlink -f "$0")")
base_dir="${script_dir}/.."

baseName=$2

if [ $# -ne 2 ]; then
    baseName=$(basename "$1")
    echo "Choosing ${baseName} as a base name for translation files"
fi

for dir in "$1"/*; do
    echo "Processing ${dir}"
    locale=$(basename "${dir}")
    targetLocale=$(echo "${locale}" | cut -f1 -d-)

    if test -f "${dir}/${baseName}.xliff"; then
        fileName="${baseName}.xliff"
        echo "Processing ${locale} xliff"

        if [ "${locale}" != "${targetLocale}" ]; then
            echo "Changing locale from '$locale' to '$targetLocale'"
            # Modify the target-language attribute
            sed -i '.bak' "s/target-language=\"${locale}\"/target-language=\"${targetLocale}\"/" "${dir}/${fileName}"
            rm "${dir}/${fileName}.bak"
        fi

        # Change state="new" to state="translated"
        echo "Changing state from 'new' to 'translated' for all entries in ${fileName}"
        sed -i '.bak' 's/state="new"/state="translated"/g' "${dir}/${fileName}"
        rm "${dir}/${fileName}.bak"

        echo "Importing ${dir}/${fileName} ..."

        if ! xcodebuild -importLocalizations -project "${base_dir}/DuckDuckGo.xcodeproj" -localizationPath "${dir}/${fileName}" APP_STORE_PRODUCT_MODULE_NAME_OVERRIDE="DuckDuckGo_Privacy_Browser_App_Store" PRIVACY_PRO_PRODUCT_MODULE_NAME_OVERRIDE="DuckDuckGo_Privacy_Browser_Privacy_Pro"; then
            echo "ERROR: Failed to import ${dir}/${fileName}"
            echo
            echo "Check translation folder and files then try again."
            echo
            exit 1
        fi
    else
        echo "ERROR: ${fileName} xliff not found in ${dir}"
        echo
        exit 1
    fi
done
