#!/bin/bash

# Get the directory where the script is stored and define paths
script_dir=$(dirname "$(readlink -f "$0")")
export_path="${script_dir}/TempLocalizationExport"
final_xliff_path="${script_dir}/assets/loc"
new_xliff_name="$1" # Optional argument for renaming the .xliff file

# Ensure the final xliff directory exists
mkdir -p "$final_xliff_path"

# Export localizations
xcodebuild -exportLocalizations -localizationPath "$export_path" -derivedDataPath "${script_dir}/DerivedData" -scheme "DuckDuckGo Privacy Browser" APP_STORE_PRODUCT_MODULE_NAME_OVERRIDE=DuckDuckGo_Privacy_Browser_App_Store PRIVACY_PRO_PRODUCT_MODULE_NAME_OVERRIDE=DuckDuckGo_Privacy_Browser_Privacy_Pro

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

# Open the directory containing the xliff file
echo "Opening directory containing the xliff file..."
case "$OSTYPE" in
  linux-gnu*) xdg-open "$final_xliff_path";;
  darwin*) open "$final_xliff_path";;
  *) echo "Cannot open directory automatically on this OS. Please navigate manually to: $final_xliff_path";;
esac
