#!/bin/bash

# Constants
S3_PATH="s3://ddg-staticcdn/macos-desktop-browser/"

# Defaults
DIRECTORY="$HOME/Developer/sparkle-updates"
PROFILE="ddg-macos"
DEBUG=0
OVERWRITE_DMG_VERSION=""

# Print the usage
function print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "This script is a tool for uploading files to AWS S3. It's designed to assist in deploying app updates."
    echo "Ensure the specified directory contains appcast2.xml, .dmg, and .delta files."
    echo ""
    echo "Options:"
    echo "  --directory <directory_path>    Path to the directory containing the files for upload. Default is '$DIRECTORY'."
    echo ""
    echo "  --overwrite-duckduckgo-dmg <version>    Specifies the version of the .dmg that should be used to overwrite duckduckgo.dmg in S3. Typically used for public releases."
    echo ""
    echo "  --debug    If set, no 'aws cp' commands will be executed. They will be printed to stdout instead."
    echo ""
    echo "Example:"
    echo "  $0 --overwrite-duckduckgo-dmg 2.0.1"
    exit 1
}

# Execute AWS command, but just echo it if in debug mode
function execute_aws() {
    AWS_CMD="$1"
    echo "$AWS_CMD"
    if [[ $DEBUG -eq 0 ]]; then
        $AWS_CMD
    fi
}

# Argument parsing
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --directory) DIRECTORY="$2"; shift ;;
        --overwrite-duckduckgo-dmg) OVERWRITE_DMG_VERSION="$2"; shift ;;
        --debug) DEBUG=1 ;;
        *) echo "Unknown parameter passed: $1"; print_usage ;;
    esac
    shift
done

# Perform AWS login
execute_aws "aws sso login --profile $PROFILE"

# Ensure appcast2.xml exists
if [[ ! -f "$DIRECTORY/appcast2.xml" ]]; then
    echo "Error: appcast2.xml not found in $DIRECTORY."
    exit 1
fi

# Extract filenames from the appcast2.xml
FILES_TO_UPLOAD=$(grep -Eo '[a-zA-Z0-9.-]+\.dmg|[a-zA-Z0-9.-]+\.delta' "$DIRECTORY/appcast2.xml")

MISSING_FILES=()

# Loop through and check if the files exist on S3 and locally
for FILENAME in $FILES_TO_UPLOAD; do
    # Check if the file exists locally
    if [[ ! -f "$DIRECTORY/$FILENAME" ]]; then
        echo "Warning: File $FILENAME does not exist locally."
        continue
    fi

    # Check if the file exists on S3
    AWS_CMD="aws --profile $PROFILE s3 ls ${S3_PATH}${FILENAME}"
    echo "Checking S3 for $FILENAME..."
    if ! $(aws --profile $PROFILE s3 ls ${S3_PATH}${FILENAME} > /dev/null 2>&1); then
        echo "$FILENAME not found on S3. Marking for upload."
        MISSING_FILES+=("$FILENAME")
    else
        echo "$FILENAME exists on S3. Skipping."
    fi
done

# Add appcast2.xml for upload last
MISSING_FILES+=("appcast2.xml")

# Notify the user about files to be uploaded
if [[ ${#MISSING_FILES[@]} -gt 0 ]]; then
    echo "The following files will be uploaded:"
    for FILE in "${MISSING_FILES[@]}"; do
        echo "$FILE"
    done

    read -p "Do you wish to continue? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Upload each missing file
for FILE in "${MISSING_FILES[@]}"; do
    AWS_CMD="aws --profile $PROFILE s3 cp $DIRECTORY/$FILE ${S3_PATH}$FILE --acl public-read"
    execute_aws "$AWS_CMD"
done

# If the overwrite flag was set, overwrite the primary dmg
if [[ ! -z "$OVERWRITE_DMG_VERSION" ]]; then
    AWS_CMD="aws --profile $PROFILE s3 cp $DIRECTORY/duckduckgo-$OVERWRITE_DMG_VERSION.dmg ${S3_PATH}duckduckgo.dmg --acl public-read"
    execute_aws "$AWS_CMD"
fi

echo "Upload complete!"
