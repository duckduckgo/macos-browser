#!/bin/bash

BROWSER_DIR=~/Library/Caches/com.duckduckgo.macos.browser.debug
OUTPUT_DIR=~/Desktop/macos-browser-audit

rm -rf $OUTPUT_DIR
mkdir -p $OUTPUT_DIR

cd $BROWSER_DIR || exit 1

find . > $OUTPUT_DIR/startup.txt

