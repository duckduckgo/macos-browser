# DuckDuckGo Privacy Browser for macOS

## Building

The app uses submodules, which will need to be cloned in order for the project to build:

Run `git submodule update --init --recursive`

## Schemes

`DuckDuckGo Privacy Browser` is the primary scheme. Use it for development, testing and releases.
Use `Product Review Release` scheme for exporting builds for a product review or product feedback request.
Use `Pull Request Testing with TSan` for testing a build in Release configuration before approving a pull request.
