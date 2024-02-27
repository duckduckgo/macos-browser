#!/bin/bash

# Get the directory where the script is stored
script_dir=$(dirname "$(readlink -f "$0")")
base_dir="${script_dir}/.."

# Define the base directory for localization export
export_path="${script_dir}/TempLocalizationExport"

# Define the final directory for the xliff file
final_xliff_path="${script_dir}/assets/loc"

# Check for an input argument to rename the .xliff file, if provided
new_xliff_name="$1"

# Ensure the final xliff directory exists
mkdir -p "$final_xliff_path"

# Export localizations
xcodebuild -exportLocalizations -localizationPath "$export_path" -derivedDataPath "${script_dir}/DerivedData" -scheme "DuckDuckGo Privacy Browser" APP_STORE_PRODUCT_MODULE_NAME_OVERRIDE=DuckDuckGo_Privacy_Browser_App_Store PRIVACY_PRO_PRODUCT_MODULE_NAME_OVERRIDE=DuckDuckGo_Privacy_Browser_Privacy_Pro

# Navigate to the exported .xloc file
cd "${export_path}" || exit

xcloc_package=$(find . -type d -name "*.xcloc")

if [ -n "$xcloc_package" ]; then
    echo "Extracting .xliff from $xcloc_package"
    # Determine the target .xliff file path
    xliff_file="en.xliff"
    if [ -n "$new_xliff_name" ]; then
        xliff_file="${new_xliff_name}.xliff"
    fi

    # Extract the .xliff file to the final path
    cp "${xcloc_package}/Localized Contents/en.xliff" "${final_xliff_path}/${xliff_file}"
    echo "Extraction complete. .xliff file is now in ${final_xliff_path} as ${xliff_file}"
else
    echo "No .xcloc package found. Exiting."
    exit 1
fi

# Cleanup
echo "Cleaning up temporary files..."
rm -rf "$export_path"
echo "Cleanup complete."

# Open the directory containing the xliff file
echo "Opening directory containing the xliff file..."
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    xdg-open "$final_xliff_path"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    open "$final_xliff_path"
else
    echo "Cannot open directory automatically on this OS. Please navigate manually to: $final_xliff_path"
fi
