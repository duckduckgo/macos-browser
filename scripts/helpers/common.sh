#!/bin/bash

#
# Output passed arguments to stderr and exit.
#
die() {
	cat >&2 <<< "$*"
	exit 1
}

random_string() {
	uuidgen | tr -d '-' | tr '[:upper:]' '[:lower:]'
}

silent_output() {
	"$@" >/dev/null 2>&1
}