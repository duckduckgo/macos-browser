#!/bin/sh

# Function to display help information
show_help() {
    echo
    echo "--- HELP ---"
    echo "Usage: $0 <translation_folder> [base_file_name]"
    echo
    echo "Arguments:"
    echo "  <translation_folder>  Mandatory. The folder containing translation files."
    echo "  [base_file_name]      Optional. The base name of the translation files. If not provided, it is derived from the folder name."
    echo
    echo "This script processes .xliff files in the specified translation folder."
    echo "It updates 'target-language' attributes and changes state from 'new' to 'translated'."
    echo "Finally, it attempts to import the processed .xliff files into an Xcode project."
    echo "--- ---"
    echo
}

# Parse command-line options
while [ $# -gt 0 ]; do
    key="$1"
    case $key in
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            break
            ;;
    esac
done

# Get the directory where the script is stored
script_dir=$(dirname "$(readlink -f "$0")")
base_dir="${script_dir}/.."

input_path=$1
baseName=$2

# Check for the presence of at least one argument
if [ $# -lt 1 ]; then
    show_help
    exit 1
fi

# Check for the presence of two arguments if second not provided the base file name is derived from the folder name."
if [ $# -lt 2 ]; then
    baseName=$(basename "$input_path" .zip)
    baseName=$(basename "$baseName" .xliff)
    echo "Choosing ${baseName} as a base name for translation files"
fi

# If input is zip file then extract it
if expr "$input_path" : '.*\.zip$' > /dev/null; then
    extraction_dir="$(dirname "$input_path")/$baseName"
    mkdir -p "$extraction_dir"
    echo "Unzipping $input_path into $extraction_dir"
    unzip -o "$input_path" -d "$extraction_dir"
    input_path="$extraction_dir"
fi

for dir in "$input_path"/*; do
    echo "Processing ${dir}"
    locale=$(basename "${dir}")
    targetLocale=$(echo "${locale}" | cut -f1 -d-)

        if test -f "${dir}/${baseName}.xliff"; then
        echo "Processing ${locale} xliff"
        fileName="${baseName}.xliff"
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

        if ! xcodebuild -importLocalizations -project "${base_dir}/DuckDuckGo-macOS.xcodeproj" -localizationPath "${dir}/${fileName}" APP_STORE_PRODUCT_MODULE_NAME_OVERRIDE="DuckDuckGo_Privacy_Browser_App_Store" PRIVACY_PRO_PRODUCT_MODULE_NAME_OVERRIDE="DuckDuckGo_Privacy_Browser_Privacy_Pro"; then
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
