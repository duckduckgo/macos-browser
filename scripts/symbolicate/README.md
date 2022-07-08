## Introduction

This script symbolicates crash logs. It supports both legacy `.crash` format as well as newer IPS format.

It will read a file and then update it with the symbolicated code.

It only runs on macOS as it requires the `atos` command.


## Installation

You need node installed to run this script.

* `brew install node`


## Configuration

You need to download the relevant debug symbols and put them in the relevant place. See binaries/README.md

# Running

Run the following command:

* `node ./symbolicate.js <path to a crash log file>`

or 

* `node ./symbolicate.js <path to folder containing .crash and/or .ips files>`
