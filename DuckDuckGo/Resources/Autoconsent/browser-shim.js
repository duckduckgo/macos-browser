let _msgCtr = 0
const tabStore = new Map()

class WebNavigationListener {
    constructor () {
        this._listeners = []
    }

    _trigger (args) {
        this._listeners.forEach(({ fn }) => fn(args))
    }

    addListener (fn, filter) {
        this._listeners.push({ fn, filter })
    }
}

window.browser = {
    webNavigation: {
        onCommitted: new WebNavigationListener(),
        onCompleted: new WebNavigationListener()
    },
    tabs: {
        get (tabId) {
            return Promise.resolve(tabStore.get(tabId))
        },
        sendMessage: (tabId, message, { frameId } = { frameId: 0 }) => {
            const messageId = _msgCtr++
            return window.webkit.messageHandlers.browserTabsMessage.postMessage(JSON.stringify({
                messageId,
                tabId,
                message,
                frameId
            }))
        }
    },
    runtime: {
        onMessage: {
            _listeners: [],
            _trigger (...args) {
                window.browser.runtime.onMessage._listeners.forEach((fn) => fn(...args))
            },
            addListener (cb) {
                window.browser.runtime.onMessage._listeners.push(cb)
            }
        }
    }
}

window._nativeMessageHandler = (tabId, frameId, message) => {
    // console.log(tabId, frameId, message)
    switch (message.type) {
    case 'webNavigation.onCommitted':
        return window.browser.webNavigation.onCommitted._trigger({
            tabId,
            frameId,
            url: message.url,
            timeStamp: Date.now()
        })
    case 'webNavigation.onCompleted':
        return window.browser.webNavigation.onCompleted._trigger({
            tabId,
            frameId,
            url: message.url,
            timeStamp: Date.now()
        })
    case 'runtime.sendMessage':
        return window.browser.runtime.onMessage._trigger(message.payload, {
            tab: {
                id: tabId
            },
            frameId
        })
    }
}

setTimeout(() => window.webkit.messageHandlers.ready.postMessage({}), 50)
