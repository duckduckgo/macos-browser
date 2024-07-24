#!/bin/bash

BROWSER_DIR=~/Library/Caches/com.duckduckgo.macos.browser.debug
OUTPUT_DIR=~/Desktop/macos-browser-audit

mkdir -p $OUTPUT_DIR

if [ "$#" -ne 2 ]; then
	echo "Usage: $(basename "$0") <this-stage> <pre-stage>"
	echo "Example: $(basename "$0") pre-burn startup"
	exit 1
fi

cd $BROWSER_DIR || exit 1

find . > $OUTPUT_DIR/"$1".txt

diff $OUTPUT_DIR/"$2".txt $OUTPUT_DIR/"$1".txt > $OUTPUT_DIR/"$1".diff

echo "Diff output:"
cat $OUTPUT_DIR/"$1".diff

