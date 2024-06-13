#!/bin/bash

BROWSER_DIR=/Users/$USER/Library/Caches/com.duckduckgo.macos.browser.debug
DESKTOP=~/Desktop

if [ "$#" -ne 2 ]; then
	echo "Usage: ./scripts/find-and-diff.sh <this-stage> <pre-stage>"
	echo "Example: ./scripts/find-and-diff.sh pre-burn startup"
	exit 1
fi

cd $BROWSER_DIR

find . > $DESKTOP/$1.txt

diff $DESKTOP/$2.txt $DESKTOP/$1.txt > $DESKTOP/$1.diff

echo "Diff output:"
cat $DESKTOP/$1.diff

