## Duck Player Settings Proxy

Register an event listener directly on `window`. This will receive events in response
to any settings YOU change and also any settings that are changed by the user (from the settings screen).

```javascript
// events will arrive here
window.addEventListener('ddg-serp-yt-response', (e) => {
    if (e.origin === window.origin) {
        console.log(e.detail) // { privatePlayerMode: { enabled: {} }, overlayInteracted: false } etc
    }
})
```

## readUserValues

Sending this will cause a new `ddg-serp-yt-response` event, use it on page-load to get the up-to-date settings

```javascript
window.dispatchEvent(new CustomEvent('ddg-serp-yt', {
    detail: {
        kind: 'readUserValues'
    }
}))
```

## setUserValues

Sending new UserValues like this, it will also cause a new `ddg-serp-yt-response` event.

```javascript
window.dispatchEvent(new CustomEvent('ddg-serp-yt', {
    detail: {
        kind: 'setUserValues',
        data: { 
            privatePlayerMode: { enabled: {} },
            overlayInteracted: true 
        }
    }
}))
```

## one-time override
To override user-settings once (for example, viewing a video from a link on the SERP), append `#play` to the
YouTube URL. If that is found + `document.referrer` is equal to `https://duckduckgo.com`, then the main video
overlay will not show (for the first video only)