#!/bin/bash

# Constants
S3_PATH="s3://ddg-staticcdn/macos-desktop-browser/"

# Defaults
DIRECTORY="$HOME/Developer/sparkle-updates"
PROFILE="ddg-macos"
DEBUG=0
OVERWRITE_DMG_VERSION=""
RUN_COMMAND=0

# Print the usage
function print_usage() {
    echo "
NAME
    upload_to_s3.sh – automation tool for uploading files to AWS S3 for macOS Desktop Browser

SYNOPSIS
    $0 --run [--directory directory_path] [--overwrite-duckduckgo-dmg version] [--debug]
    $0 --help

DESCRIPTION
    This script is a tool for uploading macOS Desktop Browser files, specifically appcast2.xml, .dmg, and .delta files, to AWS S3.

    --run
        Executes the upload process. Without this flag, the script will display the help message.

    --directory directory_path
        Specifies the directory that contains the appcast2.xml, .dmg, and .delta files. If not provided, the default value is: $DIRECTORY.

    --overwrite-duckduckgo-dmg version
        Overwrites the primary duckduckgo.dmg in S3 with the dmg version specified. This option is usually used for public releases.

    --debug
        In debug mode, no 'aws cp' commands will be executed; they will only be printed to stdout.

    --help
        Displays this help message.

EXAMPLES
    Displaying help:
        $0 --help

    Internal release (default settings):
        $0 --run

    Public release:
        $0 --run --overwrite-duckduckgo-dmg 2.0.1
"
}

# Check if AWS CLI is installed
function check_aws_installed() {
    if ! type aws > /dev/null 2>&1; then
        echo "AWS CLI not found on your system."
        echo "Please refer to the release task in Asana for instructions on how to install and configure the AWS CLI."
        echo "Once completed, run this script again."
        exit 1
    fi
}

# Check if there‘s a valid token
function check_and_login_aws_sso() {
    SSO_ACCOUNT_PROFILE=$(aws sts get-caller-identity --query "Account" --profile $PROFILE)

    if [ ${#SSO_ACCOUNT_PROFILE} -eq 14 ]; then
        echo "Session is still valid"
    else
        echo "Session has expired"
        aws sso login --profile $PROFILE
    fi
}

# Execute AWS command, but just echo it if in debug mode
function execute_aws() {
    AWS_CMD="$1"
    if [[ $DEBUG -eq 1 ]]; then
        echo "[DEBUG ONLY]: $AWS_CMD"
    else
        echo "Executing: $AWS_CMD"
        eval "$AWS_CMD"
    fi
}

# Handle SIGINT
function terminated() {
    exit 1
}

trap terminated INT

check_aws_installed

# Argument parsing
if [[ "$#" -eq 0 ]]; then
    print_usage
    exit 0
fi

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --directory) DIRECTORY="$2"; shift ;;
        --overwrite-duckduckgo-dmg) OVERWRITE_DMG_VERSION="$2"; shift ;;
        --debug) DEBUG=1 ;;
        --help) print_usage; exit 0 ;; # Display the help and exit immediately.
        --run) RUN_COMMAND=1 ;;
        *) echo "Unknown parameter passed: $1"; print_usage; exit 1 ;; # Display the help and exit with error.
    esac
    shift
done

if [[ $RUN_COMMAND -eq 0 ]]; then
    print_usage
    exit 0
fi

# Perform AWS login if needed
check_and_login_aws_sso

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
        echo "Error: File \"$DIRECTORY/$FILENAME\" listed in appcast2.xml does not exist locally."
        exit 1
    fi

    # Check if the file exists on S3
    AWS_CMD="aws --profile $PROFILE s3 ls ${S3_PATH}${FILENAME}"
    echo "Checking S3 for ${S3_PATH}${FILENAME}..."
    if ! aws --profile "$PROFILE" s3 ls "${S3_PATH}${FILENAME}" > /dev/null 2>&1; then
        echo "$FILENAME not found on S3. Marking for upload."
        MISSING_FILES+=("$FILENAME")
    else
        echo "$FILENAME exists on S3. Skipping."
    fi
done

# Create a copy of appcast2.xml called testing-appcast2.xml
# https://app.asana.com/0/0/1206349575147845/f
cp "$DIRECTORY/appcast2.xml" "$DIRECTORY/testing-appcast2.xml"
echo "Created a copy of appcast2.xml as testing-appcast2.xml"

# Add appcast files for upload
MISSING_FILES+=("appcast2.xml" "testing-appcast2.xml")

# Notify the user about files to be uploaded
if [[ ${#MISSING_FILES[@]} -gt 0 ]] || [[ -n "$OVERWRITE_DMG_VERSION" ]]; then
    if [[ ${#MISSING_FILES[@]} -gt 0 ]]; then
        echo "The following files will be uploaded:"
        for FILE in "${MISSING_FILES[@]}"; do
            echo "$FILE"
        done
    fi

    if [[ -n "$OVERWRITE_DMG_VERSION" ]]; then
        echo "The file duckduckgo-$OVERWRITE_DMG_VERSION.dmg will be used to overwrite duckduckgo.dmg on S3."
    fi

    read -p "Do you wish to continue? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Upload each missing file
for FILE in "${MISSING_FILES[@]}"; do
    AWS_CMD="aws --profile $PROFILE s3 cp \"${DIRECTORY}/${FILE}\" ${S3_PATH}${FILE} --acl public-read"
    execute_aws "$AWS_CMD" || exit 1
done

# If the overwrite flag was set, overwrite the primary dmg
if [[ -n "$OVERWRITE_DMG_VERSION" ]]; then
    AWS_CMD="aws --profile $PROFILE s3 cp \"${DIRECTORY}/duckduckgo-$OVERWRITE_DMG_VERSION.dmg\" ${S3_PATH}duckduckgo.dmg --acl public-read"
    execute_aws "$AWS_CMD" || exit 1
fi

echo "Upload complete!"
