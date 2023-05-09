#!/bin/bash

bundle_id=

case "$1" in
	debug)
		bundle_id="com.duckduckgo.macos.browser.debug"
		;;
	review)
		bundle_id="com.duckduckgo.macos.browser.review"
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

printf '%s' "Removing data for ${bundle_id}..."

defaults delete "${bundle_id}"
rm -rf "${HOME}/Library/Containers/${bundle_id}"

echo " Done."