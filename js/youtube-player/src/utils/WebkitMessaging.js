/**
 * A wrapper for sending/receiving messages
 */
export class WebkitMessaging {
    /** @type {WebkitMessagingConfig} */
    config;
    /**
     * @param {WebkitMessagingConfig} opts
     */
    constructor(opts) {
        this.config = opts;
        if (!this.config.hasModernWebkitAPI) {
            captureWebkitHandlers(this.config.webkitMessageHandlerNames)
        }
    }
    /**
     * Sends message to the webkit layer (fire and forget)
     * @param {String} handler
     * @param {*} data
     */
    wkSend (handler, data = {}) {
        if (!(handler in window.webkit.messageHandlers)) {
            throw new MissingWebkitHandler(`Missing webkit handler: '${handler}'`)
        }
        const outgoing = {...data, messageHandling: {...data.messageHandling, secret: this.config.secret}}
        if (!this.config.hasModernWebkitAPI) {
            if (!(handler in ddgGlobals.capturedWebkitHandlers)) {
                throw new Error(`cannot continue, method ${handler} not captured on macos < 11`)
            } else {
                return ddgGlobals.capturedWebkitHandlers[handler](outgoing)
            }
        }
        return window.webkit.messageHandlers[handler].postMessage?.(outgoing)
    }

    /**
     * Sends message to the webkit layer and waits for the specified response
     * @param {String} handler
     * @param {*} data
     * @returns {Promise<*>}
     */
    async wkSendAndWait(handler, data = {}) {
        if (this.config.hasModernWebkitAPI) {
            const response = await this.wkSend(handler, data)
            return ddgGlobals.JSONparse(response || '{}')
        }

        try {
            const randMethodName = createRandMethodName()
            const key = await createRandKey()
            const iv = createRandIv()

            const {ciphertext, tag} = await new ddgGlobals.Promise((resolve) => {
                generateRandomMethod(randMethodName, resolve)
                data.messageHandling = {
                    methodName: randMethodName,
                    secret: this.config.secret,
                    key: ddgGlobals.Arrayfrom(key),
                    iv: ddgGlobals.Arrayfrom(iv)
                }
                this.wkSend(handler, data)
            })

            const cipher = new ddgGlobals.Uint8Array([...ciphertext, ...tag])
            const decrypted = await decrypt(cipher, key, iv)
            return ddgGlobals.JSONparse(decrypted || '{}')
        } catch (e) {
            // re-throw when the error is a 'MissingWebkitHandler'
            if (e instanceof MissingWebkitHandler) {
                throw e
            } else {
                console.error('decryption failed', e)
                console.error(e)
                return { error: e }
            }
        }
    }
}

export class WebkitMessagingConfig {
    hasModernWebkitAPI;
    webkitMessageHandlerNames;
    secret;
    /**
     * @param {boolean} hasModernWebkitAPI
     * @param {string[]} webkitMessageHandlerNames
     * @param {string} secret
     */
    constructor(hasModernWebkitAPI, webkitMessageHandlerNames, secret) {
        this.hasModernWebkitAPI = hasModernWebkitAPI;
        this.webkitMessageHandlerNames = webkitMessageHandlerNames;
        this.secret = secret;
    }
}

class MissingWebkitHandler extends Error {
    handlerName
    constructor (handlerName) {
        super()
        this.handlerName = handlerName
    }
}

const ddgGlobals = {
    window,
    // Methods must be bound to their interface, otherwise they throw Illegal invocation
    encrypt: window.crypto.subtle.encrypt.bind(window.crypto.subtle),
    decrypt: window.crypto.subtle.decrypt.bind(window.crypto.subtle),
    generateKey: window.crypto.subtle.generateKey.bind(window.crypto.subtle),
    exportKey: window.crypto.subtle.exportKey.bind(window.crypto.subtle),
    importKey: window.crypto.subtle.importKey.bind(window.crypto.subtle),
    getRandomValues: window.crypto.getRandomValues.bind(window.crypto),
    TextEncoder,
    TextDecoder,
    Uint8Array,
    Uint16Array,
    Uint32Array,
    JSONstringify: window.JSON.stringify,
    JSONparse: window.JSON.parse,
    Arrayfrom: window.Array.from,
    Promise: window.Promise,
    ObjectDefineProperty: window.Object.defineProperty,
    addEventListener: window.addEventListener.bind(window),
    capturedWebkitHandlers: {}
}


/**
 * Generate a random method name and adds it to the global scope
 * The native layer will use this method to send the response
 * @param {String} randomMethodName
 * @param {Function} callback
 */
const generateRandomMethod = (randomMethodName, callback) => {
    ddgGlobals.ObjectDefineProperty(ddgGlobals.window, randomMethodName, {
        enumerable: false,
        // configurable, To allow for deletion later
        configurable: true,
        writable: false,
        value: (...args) => {
            callback(...args)
            delete ddgGlobals.window[randomMethodName]
        }
    })
}

const randomString = () =>
    '' + ddgGlobals.getRandomValues(new ddgGlobals.Uint32Array(1))[0]

const createRandMethodName = () => '_' + randomString()

const algoObj = {name: 'AES-GCM', length: 256}
const createRandKey = async () => {
    const key = await ddgGlobals.generateKey(algoObj, true, ['encrypt', 'decrypt'])
    const exportedKey = await ddgGlobals.exportKey('raw', key)
    return new ddgGlobals.Uint8Array(exportedKey)
}

const createRandIv = () => ddgGlobals.getRandomValues(new ddgGlobals.Uint8Array(12))

const decrypt = async (ciphertext, key, iv) => {
    const cryptoKey = await ddgGlobals.importKey('raw', key, 'AES-GCM', false, ['decrypt'])
    const algo = { name: 'AES-GCM', iv }

    let decrypted = await ddgGlobals.decrypt(algo, cryptoKey, ciphertext)

    let dec = new ddgGlobals.TextDecoder()
    return dec.decode(decrypted)
}

/**
 * When required (such as on macos 10.x), capture the `postMessage` method on
 * each webkit messageHandler
 *
 * @param {string[]} handlerNames
 */
export function captureWebkitHandlers (handlerNames) {
    for (let webkitMessageHandlerName of handlerNames) {
        if (typeof window.webkit.messageHandlers?.[webkitMessageHandlerName]?.postMessage === 'function') {
            /**
             * `bind` is used here to ensure future calls to the captured
             * `postMessage` have the correct `this` context
             */
            ddgGlobals.capturedWebkitHandlers[webkitMessageHandlerName] = window.webkit.messageHandlers[webkitMessageHandlerName].postMessage?.bind(window.webkit.messageHandlers[webkitMessageHandlerName])
            delete window.webkit.messageHandlers[webkitMessageHandlerName].postMessage
        }
    }
}
