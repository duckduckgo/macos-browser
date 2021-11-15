# DuckDuckGo Privacy Browser for macOS

## Building

The app uses submodules, which will need to be cloned in order for the project to build:

Run `git submodule update --init --recursive`

### ESLint

The app uses ESLint for checking JavaScript and is installed independently.

To install the latest node: `brew install node`.

Run `npm install` to install all the dependencies.

To check the JavaScript run `npx eslint .` and `npx eslint . --fix` to run automated fixing.

## Schemes

`DuckDuckGo Privacy Browser` is the primary scheme. Use it for development, testing and internal releases.
Use `External Beta Release` scheme for building external releases.
Use `Product Review Release` scheme for exporting builds for a review.
Use `Pull Request Testing with TSan` for testing a build in Release configuration before approving a pull request.
