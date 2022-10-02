# Youtube 

## `youtube-inject.js`

`youtube-inject.js` is the entry point for the JavaScript Bundle that's used by `YoutubeOverlayUserScript.swift` 

In the root of this project, first run `npm install` with at least `node 16`, and then run `npm run build-yt`, 
or `npm run build-yt:watch` to have it re-compile after every change.

**note** when you 'build' the JavaScript bundle, changes to the compiled artifact `youtube-inject-bundle.js` should
also be checked in when you commit.