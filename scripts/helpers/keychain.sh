#!/bin/bash

keychain_label_name="DuckDuckGo macOS Browser Scripts"

clear_keychain() {
	while security delete-generic-password -l "${keychain_label_name}" >/dev/null 2>&1; do
		true
	done
	echo "Removed keychain entries used by the script."
	exit 0
}

is_item_in_keychain() {
	local account="$1"
	local label="${2:-${keychain_label_name}}"
	security find-generic-password \
		-l "${label}" \
		-a "${account}" \
		>/dev/null 2>&1
}

retrieve_item_from_keychain() {
	local account="$1"
	local label="${2:-${keychain_label_name}}"
	security find-generic-password \
		-l "${label}" \
		-a "${account}" \
		-w \
		2>&1
}

store_item_in_keychain() {
	local account="$1"
	local item="$2"
	local label="${3:-${keychain_label_name}}"
	security add-generic-password \
		-l "${label}" \
		-a "${account}" \
		-s "" \
		-w "${item}"
}

delete_item_from_keychain() {
	local account="$1"
	local label="${2:-${keychain_label_name}}"
	security delete-generic-password \
		-l "${label}" \
		-a "${account}" \
		>/dev/null 2>&1
}
