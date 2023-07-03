# NetworkProtection

## We are hiring!

DuckDuckGo is growing fast and we continue to expand our fully distributed team. We embrace diverse perspectives, and seek out passionate, self-motivated people, committed to our shared vision of raising the standard of trust online. If you are a senior software engineer capable in either iOS or Android, visit our [careers](https://duckduckgo.com/hiring/#open) page to find out more about our openings!

## What is it?

`BrowserServicesKit` is a narrowly scoped package that contains modules shared between DuckDuckGo projects.

## Building

The package uses submodules, which will need to be cloned in order for the project to build:

Run `git submodule update --init --recursive`

`BrowserServicesKit` can be built manually two ways:

1. Build the `BrowserServicesKit` scheme by opening the Swift package in Xcode
2. Run `swift build -c release` to build a release binary


## Testing

Run `swift test` on the project root folder. Please note that running the tests on Xcode will not work.


### SwiftLint

We use [SwiftLint](https://github.com/realm/SwiftLint) for enforcing Swift style and conventions, so you'll need to [install it](https://github.com/realm/SwiftLint#installation).

## License

DuckDuckGo is distributed under the Apache 2.0 [license](https://github.com/duckduckgo/BrowserServicesKit/blob/main/LICENSE).
