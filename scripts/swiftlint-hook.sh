#!/bin/bash

# URL where the installation/uninstallation script is hosted
SCRIPT_URL="https://raw.githubusercontent.com/duckduckgo/BrowserServicesKit/daniel/swiftlint-hook/scripts/swiftlint-hook.sh"

# Check the argument for install or uninstall
if [ "$1" != "--install" ] && [ "$1" != "--uninstall" ]; then
  echo "Usage: $0 --install | --uninstall"
  exit 1
fi

# Download and execute the script with the given option
if command -v curl >/dev/null; then
  curl -s "$SCRIPT_URL" | bash -s "$1"
elif command -v wget >/dev/null; then
  wget -O - "$SCRIPT_URL" | bash -s "$1"
else
  echo "error: Neither curl nor wget are available on your system. Please install one of them to proceed."
  exit 1
fi

echo "Operation completed!"