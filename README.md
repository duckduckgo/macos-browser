# DuckDuckGo Privacy Browser for macOS

## Building

The app uses submodules, which will need to be cloned in order for the project to build:

Run `git submodule update --init --recursive`

## Schemes

`DuckDuckGo Browser` is the Primary Scheme. Use it for development, testing and Internal Releases.
Use `DuckDuckGo PR test RELEASE with TSan` for testing a build in RELEASE mode before approving a Pull Request.
Use `DuckDuckGo Release External Beta` scheme for building External Beta Testing RELEASE builds .
