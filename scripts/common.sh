#!/bin/bash

die() {
	cat >&2 <<< "$*"
	exit 1
}