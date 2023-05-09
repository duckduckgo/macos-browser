#!/bin/bash

keychain_service_name="ddg-macos-app-archive-script"

clear_keychain() {
	while security delete-generic-password -s "${keychain_service_name}" >/dev/null 2>&1; do
		true
	done
	echo "Removed keychain entries used by the script."
	exit 0
}

is_item_in_keychain() {
	local account="$1"
	security find-generic-password \
		-s "${keychain_service_name}" \
		-a "${account}" \
		>/dev/null 2>&1
}

retrieve_item_from_keychain() {
	local account="$1"
	security find-generic-password \
		-s "${keychain_service_name}" \
		-a "${account}" \
		-w \
		2>&1
}

store_item_in_keychain() {
	local account="$1"
	local item="$2"
	security add-generic-password \
		-s "${keychain_service_name}" \
		-a "${account}" \
		-w "${item}"
}
