#!/bin/bash

delete_data() {
	bundle_id="$1"

	printf '%s' "Deleting data for ${bundle_id}..."

	if defaults read "${bundle_id}" &>/dev/null; then
		defaults delete "${bundle_id}"
	fi
	rm -rf "${HOME}/Library/Containers/${bundle_id}/Data"

	echo " Done."
}

bundle_id=

case "$1" in
	debug)
		bundle_id="com.duckduckgo.macos.browser.debug"
		netp_bundle_ids_glob="*com.duckduckgo.macos.browser.network-protection*debug"
		;;
	review)
		bundle_id="com.duckduckgo.macos.browser.review"
		netp_bundle_ids_glob="*com.duckduckgo.macos.browser.network-protection*review"
		;;
	debug-appstore)
		bundle_id="com.duckduckgo.mobile.ios.debug"
		;;
	review-appstore)
		bundle_id="com.duckduckgo.mobile.ios.review"
		;;
	*)
		echo "usage: clean-app debug|review|debug-appstore|review-appstore"
		exit 1
		;;
esac

delete_data "${bundle_id}"

if [[ -n "${netp_bundle_ids_glob}" ]]; then
	# shellcheck disable=SC2046
	read -r -a netp_bundle_ids <<< $(
		find "${HOME}/Library/Containers/" \
			-type d \
			-maxdepth 1 \
			-name "${netp_bundle_ids_glob}" \
			-exec basename {} \;
	)
	for netp_bundle_id in "${netp_bundle_ids[@]}"; do
		delete_data "${netp_bundle_id}"
	done
fi
