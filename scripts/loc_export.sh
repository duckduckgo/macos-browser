#!/bin/bash

# Function to display help information
show_help() {
    echo
    echo "---HELP---"
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo
    echo "Options:"
    echo "  -n, --name NAME    Specify the name for the exported xliff file"
    echo "This script attempts to export an xliff file from the Xcode String Catalogue."
    echo "--- ---"
    echo
    exit 0
}

# Check if xmlstarlet is installed
if ! command -v xmlstarlet &> /dev/null
then
    echo "xmlstarlet could not be found. Please install xmlstarlet."
    echo "You can install xmlstarlet using Homebrew:"
    echo " brew install xmlstarlet"
    exit 1
fi

# Parse command-line options
while [ $# -gt 0 ]; do
    key="$1"
    case $key in
        -h|--help)
            show_help
            ;;
        -n|--name)
            new_xliff_name="$2"
            shift # past argument
            shift # past value
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            ;;
    esac
done

# Get the directory where the script is stored and define paths
script_dir=$(dirname "$(readlink -f "$0")")
export_path="${script_dir}/TempLocalizationExport"
final_xliff_path="${script_dir}/assets/loc"

# Ensure the final xliff directory exists
mkdir -p "$final_xliff_path"

# Export localizations
xcodebuild -exportLocalizations -localizationPath "$export_path" -derivedDataPath "${script_dir}/DerivedData" -scheme "macOS Browser" APP_STORE_PRODUCT_MODULE_NAME_OVERRIDE=DuckDuckGo_Privacy_Browser_App_Store PRIVACY_PRO_PRODUCT_MODULE_NAME_OVERRIDE=DuckDuckGo_Privacy_Browser_Privacy_Pro

# Attempt to find the .xcloc package
xcloc_package=$(find "$export_path" -type d -name "*.xcloc")

# Check if .xcloc package was found and proceed
if [ -z "$xcloc_package" ]; then
    echo "No .xcloc package found. Exiting."
    exit 1
fi

echo "Extracting .xliff from $xcloc_package"
xliff_file="${new_xliff_name:-en}.xliff" # Use provided name or default to "en.xliff"

# Extract the .xliff file to the final path
cp "${xcloc_package}/Localized Contents/en.xliff" "${final_xliff_path}/${xliff_file}"
echo "Extraction complete. .xliff file is now in ${final_xliff_path} as ${xliff_file}"

# Cleanup
echo "Cleaning up temporary files..."
rm -rf "$export_path"
echo "Cleanup complete."

# Define an array of unwanted paths
declare -a unwanted_paths=(
    "DuckDuckGoDBPBackgroundAgent/Info-AppStore-InfoPlist.xcstrings"
    "DuckDuckGoDBPBackgroundAgent/InfoPlist.xcstrings"
    "DuckDuckGoDBPBackgroundAgent/Localizable.xcstrings"
    "DuckDuckGoNotifications/InfoPlist.xcstrings"
    "DuckDuckGoNotifications/Localizable.xcstrings"
    "DuckDuckGoVPN/Info-AppStore-InfoPlist.xcstrings"
    "DuckDuckGoVPN/InfoPlist.xcstrings"
    "NetworkProtectionAppExtension/Info.plist"
    "NetworkProtectionAppExtension/InfoPlist.xcstrings"
    "VPNProxyExtension/InfoPlist.xcstrings"
    "DuckDuckGo/Suggestions/View/Base.lproj/Suggestion.storyboard"
    "sandbox-test-tool/Info.plist"
    "sandbox-test-tool/InfoPlist.xcstrings"
)

# Loop through each unwanted path and remove the corresponding <file> elements
for path in "${unwanted_paths[@]}"; do
    echo "Removing entries for $path from the .xliff file..."
    xmlstarlet ed --inplace -N x="urn:oasis:names:tc:xliff:document:1.2" \
        -d "//x:file[contains(@original, '$path')]" \
        "${final_xliff_path}/${xliff_file}"
done

echo "Modification of .xliff file complete."

# Open the directory containing the xliff file
open "${final_xliff_path}"
