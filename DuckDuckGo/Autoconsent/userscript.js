import handleContentMessage from '@cliqz/autoconsent/lib/web/content'

window.autoconsent = (payload) => {
    return handleContentMessage(payload.message, false)
}

window.webkit.messageHandlers.autoconsentBackgroundMessage.postMessage(JSON.stringify({
    type: 'webNavigation.onCommitted',
    url: window.location.href
}))

const isMainDocument = window === window.top
if (isMainDocument) {
    setTimeout(() => {
        window.webkit.messageHandlers.autoconsentPageReady.postMessage(window.location.href)
    }, 100)
}

window.onload = () => {
    window.webkit.messageHandlers.autoconsentBackgroundMessage.postMessage(JSON.stringify({
        type: 'webNavigation.onCompleted',
        url: window.location.href
    }))
    if (isMainDocument) {
        window.webkit.messageHandlers.autoconsentPageReady.postMessage(window.location.href)
    }
}
