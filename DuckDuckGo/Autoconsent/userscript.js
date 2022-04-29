import handleContentMessage from '@duckduckgo/autoconsent/lib/web/content'

window.autoconsent = (payload) => {
    return handleContentMessage(payload.message, false)
}

window.webkit.messageHandlers.autoconsentBackgroundMessage.postMessage(JSON.stringify({
    type: 'webNavigation.onCommitted',
    url: window.location.href
}))

const isMainDocument = window === window.top

function onLoad() {
    window.webkit.messageHandlers.autoconsentBackgroundMessage.postMessage(JSON.stringify({
        type: 'webNavigation.onCompleted',
        url: window.location.href
    }))
    if (isMainDocument) {
        window.webkit.messageHandlers.autoconsentPageReady.postMessage(window.location.href)
    }
}

if (document.readyState === 'loading') {
    window.addEventListener('DOMContentLoaded', onLoad);
} else {
    onLoad();
}
