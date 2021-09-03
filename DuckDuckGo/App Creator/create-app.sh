#!/bin/sh

#  create-app.sh
#  DuckDuckGo
#
#  Created by Tomas Strba on 02/09/2021.
#  Copyright © 2021 DuckDuckGo. All rights reserved.

readonly IMAGE_FILE=$1
echo $IMAGE_FILE
readonly APP_NAME=$2
echo $APP_NAME
readonly APP_LINK=$3
echo $APP_LINK
readonly BUNDLE_PATH="$HOME/Applications/DuckDuckGo Apps/$APP_NAME.app"
readonly CONTENTS_BUNDLE_PATH="$BUNDLE_PATH/Contents"
readonly MACOS_BUNDLE_PATH="$CONTENTS_BUNDLE_PATH/MacOS"
readonly RESOURCES_BUNDLE_PATH="$CONTENTS_BUNDLE_PATH/Resources"
readonly LOADER_BUNDLE_PATH="$MACOS_BUNDLE_PATH/app_mode_loader"
readonly ICON_BUNDLE_PATH="$RESOURCES_BUNDLE_PATH/app.icns"
readonly PLIST_BUNDLE_PATH="$CONTENTS_BUNDLE_PATH/Info.plist"

readonly BUNDLE_ID_POSTFIX=$(openssl rand -base64 12)

PLIST="<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\">
<dict>
        <key>CFBundleDevelopmentRegion</key>
        <string>en</string>
        <key>CFBundleExecutable</key>
        <string>app_mode_loader</string>
        <key>CFBundleIconFile</key>
        <string>app.icns</string>
        <key>CFBundleIdentifier</key>
        <string>com.duckduckgo.macos.$BUNDLE_ID_POSTFIX</string>
        <key>CFBundleInfoDictionaryVersion</key>
        <string>6.0</string>
        <key>CFBundleName</key>
        <string>$APP_NAME</string>
        <key>CFBundlePackageType</key>
        <string>APPL</string>
        <key>CFBundleShortVersionString</key>
        <string></string>
        <key>CFBundleSignature</key>
        <string>????</string>
        <key>CFBundleVersion</key>
        <string>29.76</string>
        <key>LSEnvironment</key>
        <dict>
                <key>MallocNanoZone</key>
                <string>0</string>
        </dict>
        <key>LSHasLocalizedDisplayName</key>
        <true/>
        <key>LSMinimumSystemVersion</key>
        <string>10.11.0</string>
        <key>NSAppleScriptEnabled</key>
        <true/>
        <key>NSHighResolutionCapable</key>
        <true/>
</dict>
</plist>"

LOADER="#!/bin/bash

/Applications/DuckDuckGo.app/Contents/MacOS/DuckDuckGo --app=$APP_LINK"

mkdir -p "$CONTENTS_BUNDLE_PATH" "$MACOS_BUNDLE_PATH" "$RESOURCES_BUNDLE_PATH"
echo "$PLIST" > "$PLIST_BUNDLE_PATH"
echo "$LOADER" > "$LOADER_BUNDLE_PATH"
chmod 755 "$LOADER_BUNDLE_PATH"
sips -s format icns "$IMAGE_FILE" --out "$ICON_BUNDLE_PATH" || true

sleep 1
open "$BUNDLE_PATH"
