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
	local service="${2:-${keychain_service_name}}"
	security find-generic-password \
		-s "${service}" \
		-a "${account}" \
		>/dev/null 2>&1
}

retrieve_item_from_keychain() {
	local account="$1"
	local service="${2:-${keychain_service_name}}"
	security find-generic-password \
		-s "${service}" \
		-a "${account}" \
		-w \
		2>&1
}

store_item_in_keychain() {
	local account="$1"
	local item="$2"
	local service="${3:-${keychain_service_name}}"
	security add-generic-password \
		-s "${service}" \
		-a "${account}" \
		-w "${item}"
}

is_item_in_keychain_by_label() {
	local account="$1"
	local label="$2"
	security find-generic-password \
		-l "${label}" \
		-a "${account}" \
		>/dev/null 2>&1
}

retrieve_item_from_keychain_by_label() {
	local account="$1"
	local label="$2"
	security find-generic-password \
		-l "${label}" \
		-a "${account}" \
		-w \
		2>&1
}

delete_item_from_keychain_with_label() {
	local account="$1"
	local label="$2"
	security delete-generic-password \
		-l "${label}" \
		-a "${account}" \
		>/dev/null 2>&1
}

store_item_in_keychain_with_label() {
	local account="$1"
	local item="$2"
	local label="$3"
	security add-generic-password \
		-l "${label}" \
		-s '' \
		-a "${account}" \
		-w "${item}"
}
