# DuckDuckGo for macOS

We are excited to engage the community in development!

## We are hiring!
DuckDuckGo is growing fast and we continue to expand our fully distributed team. We embrace diverse perspectives, and seek out passionate, self-motivated people, committed to our shared vision of raising the standard of trust online. If you are a senior software engineer, visit our [careers](https://duckduckgo.com/hiring/#open) page to find out more about our openings!

## Building

### Submodules
We use submodules, so you will need to bring them into the project in order to build and run it:

Run `git submodule update --init --recursive`

### Developer details
If you're not part of the DuckDuckGo team, go to Signing & Capabilities to select your team and custom bundle identifier.

### Dependencies
We use Swift Package Manager for dependency management, which shouldn't require any additional set up.

### SwiftLint
We use [SwifLint](https://github.com/realm/SwiftLint) for enforcing Swift style and conventions, so you'll need to [install it](https://github.com/realm/SwiftLint#installation).

### Duck player

To build the JS for Duck Player:

1. First run `npm install` - please ensure you have `node 16` or above.
2. Then run `npm run build-yt` - this will build from `js/youtube-player` & copy the artifact into `DuckDuckGo/Youtube Player/Resources/youtube-inject-bundle.js`.
3. To have it continuously re-compile, run `npm run build-yt:watch`.

Notes for Duck Player

- `youtube-inject.js` is the entry point for the JavaScript Bundle that's used by `YoutubeOverlayUserScript.swift`
- When you 'build' the JavaScript bundle, changes to the compiled artifact `youtube-inject-bundle.js` should also be checked in when you commit.
- If you make any changes, please run the integration tests:
  - `cd js/youtube-player && npm run test.integration`

## Terminology

We have taken steps to update our terminology and remove words with problematic racial connotations, most notably the change to `main` branches, `allow lists`, and `blocklists`. Closed issues or PRs may contain deprecated terminology that should not be used going forward.

## Contribute

Please refer to [contributing](CONTRIBUTING.md).

## Discuss

Contact us at https://duckduckgo.com/feedback if you have feedback, questions or want to chat. You can also use the feedback form embedded within our app - to do so please go to Main Menu -> Help -> Send Feedback. 

## License
DuckDuckGo is distributed under the Apache 2.0 [license](LICENSE.md).
