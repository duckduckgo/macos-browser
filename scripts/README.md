# Scripts

* [archive.sh](#archivesh-create-notarized-application-build)
* [find-private-symbols.sh](#find-private-symbolssh-check-a-binary-for-private-api-usage)
* [update-embedded.sh](#update-embeddedsh-update-embedded-tracker-data-set-and-privacy-config)

## `archive.sh`: Create notarized application build

This script allows to create notarized application builds. It's primarily 
used by GitHub Actions release workflow, but it can also be run locally
as needed.

### Features

1. Makes notarized builds for Product Reviews and public releases.
1. Outputs the app and compressed dSYMs.
1. Can optionally output a DMG image ready for distribution.
1. If making a public release, it can update the Asana release task passed as
  a parameter; it will then upload the DMG and dSYMs to the task, and mark
  relevant subtasks as complete.

### Software Requirements

To run locally you'll need a valid installation of Xcode. Make sure that 
`xcode-select -p` prints out the path to Developer directory inside Xcode.app
bundle, e.g. `/Applications/Xcode-13.3.0.app/Contents/Developer`.

Optionally you'll need:
* `create-dmg`, to create DMG images,
* `jq`, to handle Asana tasks,
* `xcpretty`, to beautify `xcodebuild` output.

### Setting up accounts and accesses

#### Apple

App notarization happens on Apple servers and the app can only be uploaded by
an authorized member of the DDG Apple Developer Program. The script currently
does not support multi-factor authentication, which means that you'd have to
create an _app-specific password_ for your Apple ID associated with the
developer account:

1. Go to https://appleid.apple.com/ and sign in.
1. Select App-specific passwords
1. Add new password using `+` button
1. Copy the password and pass it to the script when asked. The password will
  be securely stored in your login keychain for later use.

#### Asana

To use Asana integration, you'll need to create Asana Personal Access Token:

1. Go to https://app.asana.com/0/my-apps.
1. Select _Create new token_ and follow on-screen instructions.
1. Copy the generated token and pass it to the script when asked. The token
  will be securely stored in your login keychain for later use. Any updates
  to Asana tasks made by your instance of the script will be performed as
  your user (because it's your _personal_ token).

### Usage

To make a review build:

    $ ./scripts/archive.sh review

To make a release build and a DMG:

    $ ./scripts/archive.sh release -d

Display all available parameters:

    $ ./scripts/archive.sh -h


## `find-private-symbols.sh`: Check a binary for private API usage

This script checks a compiled app binary for references to private Obj-C selectors.
_Private_ is defined by _starting with an underscore_. It uses `otool` to retrieve
Obj-C selector pointers from the binary (see [this SO answer](https://stackoverflow.com/a/15829049)
for a bit more info). Results are then filtered and formatted and if there are any
selectors on the list that start with an underscore, the check fails
and outputs an error message.

### Requirements

No 3rd party software is required to run the script. It uses built-in
macOS toolchain utilities: lipo and otool.

### Usage

The check should work for any release build, but for debug builds it only works when
the binary is compiled for both x86_64 and arm64 architectures, hence by default
this is checked. The check can be skipped with a `-f` flag.

To check for private API symbols in the app:

    $ ./scripts/find_private_symbols.sh DuckDuckGo.app/Contents/MacOS/DuckDuckGo


## `update-embedded.sh`: Update embedded Tracker Data Set and Privacy Config

This script checks app's source code for ETag values of Tracker Data Set
and Privacy Config files embedded in the app, downloads new versions of the
files if they appear outdated and updates relevant entries in the source code
to reflect the metadata (ETag and SHA256 sum) of downloaded files.

It may update the following files:
* DuckDuckGo/Content Blocker/AppPrivacyConfigurationDataProvider.swift
* DuckDuckGo/Content Blocker/AppTrackerDataSetProvider.swift
* DuckDuckGo/Content Blocker/macos-config.json
* DuckDuckGo/Content Blocker/trackerData.json

### Requirements

No 3rd party software is required to run the script. It uses built-in
command line utilities and curl.

### Usage

To update embedded files if needed:

    $ ./scripts/update_embedded.sh

Make sure that unit tests pass after updating files. These test cases verify
embedded data correctness:
* `EmbeddedTrackerDataTests.testWhenEmbeddedDataIsUpdatedThenUpdateSHAAndEtag`
* `AppPrivacyConfigurationTests.testWhenEmbeddedDataIsUpdatedThenUpdateSHAAndEtag`
