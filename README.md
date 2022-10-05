# DuckDuckGo Privacy Browser for macOS

## Building

The app uses submodules, which will need to be cloned in order for the project to build:

Run `git submodule update --init --recursive`

## Schemes

`DuckDuckGo Privacy Browser` is the primary scheme. Use it for development, testing and releases.
Use `Product Review Release` scheme for exporting builds for a product review or product feedback request.
Use `Pull Request Testing with TSan` for testing a build in Release configuration before approving a pull request.

## Duck player

To build the JS for the duck player:

- first run `npm install` - please ensure you have `node 16` or above
- then run `npm run build-yt` - this will build from `js/youtube-player` & copy the artifact into `DuckDuckGo/Youtube Player/Resources/youtube-inject-bundle.js`
- to have it continuously re-compile, run `npm run build-yt:watch`

Notes for Duck Player

- `youtube-inject.js` is the entry point for the JavaScript Bundle that's used by `YoutubeOverlayUserScript.swift`
- when you 'build' the JavaScript bundle, changes to the compiled artifact `youtube-inject-bundle.js` should also be checked in when you commit.
