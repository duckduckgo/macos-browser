
## Introduction

This script symbolicates IPS crashes.  

It will read an IPS file and then update it with the symbolicated code.  

It only runs on macOS as it requires the `atos` command.


## Installation

You need node installed to run this script.

* `brew install node`


## Configuration

You need to download the relevant binaries and put them in the relevant place. See binaries/README.md


# Running

Run the following command:

* `node ./symbolicate.js <path to IPS file>`

or 

* `node ./symbolicate.js <path to folder containing .ips files>`

In this second mode the files must have the .ips extension.
