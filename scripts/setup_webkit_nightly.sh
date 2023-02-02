#!/bin/bash

set -e

pwd="$(pwd)"

if ! [[ $common_sh ]]; then
	cwd="$(dirname "${BASH_SOURCE[0]}")"
	source "${cwd}/helpers/common.sh"
fi

download_and_unpack() {
	local webkit_url="${1:-https://s3-us-west-2.amazonaws.com/minified-archives.webkit.org/mac-ventura-x86_64%20arm64-release/259749@main.zip}"
	local tempdir
	tempdir="$(mktemp -d)"
	trap 'rm -rf "$tempdir"' EXIT

	echo "Using archive at ${webkit_url}"
	printf '%s' "Downloading WebKit nightly build ... "
	wget -q "${webkit_url}" -O "${tempdir}/webkit.zip"
	echo "✅"

	printf '%s' "Unpacking ... "
	unzip -qq "${tempdir}/webkit.zip" -d "${tempdir}"
	echo "✅"

	printf '%s' "Moving files into place ... "
	rm -rf "${pwd}/WebKit"
	mkdir -p "${pwd}/WebKit"
	mv -f "${tempdir}/Release/libANGLE-shared.dylib" \
	    "${tempdir}/Release/libwebrtc.dylib" \
		"${tempdir}/Release/JavaScriptCore.framework" \
		"${tempdir}/Release/WebCore.framework" \
		"${tempdir}/Release/WebInspectorUI.framework" \
		"${tempdir}/Release/WebKit.framework" \
		"${tempdir}/Release/WebKitLegacy.framework" \
		"${pwd}/WebKit"
	echo "✅"
}

download_and_unpack "$@"