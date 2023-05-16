#!/bin/bash

# Redirect all output to a file
output_file="output.txt"
exec > "${output_file}" 2>&1

# built app path
APP_PATH="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app"

script_name=$(basename "$0")
echo "running ${script_name}"

# when SIP is enabled we need to run the app from the /Applications dir
if [ "$(csrutil status)" = "System Integrity Protection status: enabled." ]; then
  echo "SIP is enabled"

  # show warning message
  alert_shown=$(defaults read com.apple.dt.Xcode "ddg_netp_install_to_apps")
  if [ "$alert_shown" != 1 ]; then
    response=$(osascript -e 'display alert "With System Integrity Protection enabled you need to install the App into the /Applications folder, do you want to proceed?" buttons {"Cancel", "Install"} default button "Cancel"')
    if [ "$response" == "button returned:Install" ]; then
      # remember the choice
      defaults write com.apple.dt.Xcode "ddg_netp_install_to_apps" -bool true
    else
      exit 1
    fi
  fi

  # install path to the app in the /Applications dir
  INSTALL_PATH="/Applications/${PRODUCT_NAME}.app"
  should_install=true

  # already installed?
  if [[ -d "${INSTALL_PATH}" ]]; then
    echo "app installed"
    # app is running?
    if pgrep -xq -- "${PRODUCT_NAME}"; then
      echo "app is running: closing"
      # close the app
      osascript -e "quit app \"${PRODUCT_NAME}\""
    fi

    diff=(diff -rq \"${APP_PATH}\" \"${INSTALL_PATH}\")
    if [ -z "$diff" ]; then
      echo "bundles are same"
      # bundles are same
      should_install=false
    fi

    if [ "$should_install" = true ]; then
      echo "removing bundle at ${INSTALL_PATH}"
      # automatically confirm the app-with-sysex removal dialog in Finder
      (exec osascript "${SRCROOT}/scripts/finder_conform_dialog.scpt" "${PRODUCT_NAME}.app") >> "${output_file}" 2>&1 &

      # remove the app bundle
      osascript -e "tell app \"Finder\" to delete POSIX file \"${INSTALL_PATH}\""
    fi
    if [[ -d "${INSTALL_PATH}" ]]; then
      echo "it‘s still there!!! removing again"
      # remove the app bundle
      osascript -e "tell app \"Finder\" to delete POSIX file \"${INSTALL_PATH}\""
    fi
  else
    echo "app is not installed at ${INSTALL_PATH}"
  fi

  # copy app to the install path
  if [ "$should_install" = true ]; then
    echo "copying ${APP_PATH} to ${INSTALL_PATH}"
    cp -R "${APP_PATH}" /Applications/
  fi

  APP_PATH="${INSTALL_PATH}"
fi

echo "launching ${APP_PATH}"
# launch!
(sleep 1 && open -a "${APP_PATH}") &
