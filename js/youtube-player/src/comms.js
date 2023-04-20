import {WebkitMessagingConfig, Messaging} from "@duckduckgo/content-scope-utils/lib/messaging.js";
import * as constants from "../constants";

/**
 * A wrapper for cross-platform communications.
 *
 * Please see https://duckduckgo.github.io/content-scope-utils/modules/Webkit_Messaging for the underlying
 * messaging primitives.
 */
export class Communications {
    /** @type {Messaging} */
    messaging;
    /**
     * @param {Messaging} messaging
     * @param {{updateStrategy: "window-method" | "polling"}} options
     */
    constructor(messaging, options) {
        this.messaging = messaging;
        this.options = options;
    }
    /**
     * Inform the native layer that an interaction occurred
     * @param {import("../youtube-inject.js").UserValues} userValues
     * @returns {Promise<import("../youtube-inject").UserValues>}
     */
    async setUserValues(userValues) {
        return this.messaging.request(constants.MSG_NAME_SET_VALUES, userValues)
    }
    async readUserValues() {
        return this.messaging.request(constants.MSG_NAME_READ_VALUES, {})
    }

    /**
     * @param {Pixel} pixel
     */
    sendPixel(pixel) {
        this.messaging.notify(constants.MSG_NAME_PIXEL, {
            pixelName: pixel.name(),
            params: pixel.params()
        })
    }
    openInDuckPlayerViaMessage(href) {
        return this.messaging.notify(constants.MSG_NAME_OPEN_PLAYER, {href})
    }
    /**
     * Get notification when preferences/state changed
     * @param cb
     * @param {import("../youtube-inject.js").UserValues} [initialUserValues]
     */
    onUserValuesNotification(cb, initialUserValues) {
        if (this.options.updateStrategy === "window-method") {
            /**
             * @typedef UserValuesNotification
             * @property {import("../youtube-inject.js").UserValues} userValuesNotification
             *
             * This is how macOS 11+ receives updates
             *
             * @param {UserValuesNotification} values
             */
            window[constants.MSG_NAME_PUSH_DATA] = function(values) {
                if (!values?.userValuesNotification) {
                    console.error("missing userValuesNotification");
                    return;
                }
                cb(values.userValuesNotification)
            }
        }
        if (this.options.updateStrategy === "polling" && initialUserValues) {
            /**
             * On macOS < 11 (Catalina) we need to poll the native side to receive
             * notifications of any preferences changes
             */
            let timeout;
            let prevMode = Object.keys(initialUserValues.privatePlayerMode)?.[0];
            let prevInteracted = initialUserValues.overlayInteracted;
            const poll = () => {
                clearTimeout(timeout)
                timeout = setTimeout(async () => {
                    try {
                        const userValues = await this.readUserValues();
                        let nextMode = Object.keys(userValues.privatePlayerMode)?.[0];
                        let nextInteracted = userValues.overlayInteracted;
                        if (nextMode !== prevMode || nextInteracted !== prevInteracted) {
                            prevMode = nextMode
                            prevInteracted = nextInteracted
                            cb(userValues)
                        }
                        poll()
                    } catch (e) {
                        // on error we just stop polling
                    }
                }, 1000);
            }
            poll();
        }
    }

    /**
     * This allows our SERP to interact with Duck Player settings.
     */
    serpProxy() {
        function respond(kind, data) {
            window.dispatchEvent(new CustomEvent(constants.MSG_NAME_PROXY_RESPONSE, {
                detail: { kind, data },
                composed: true,
                bubbles: true
            }))
        }

        // listen for setting and forward to the SERP window
        this.onUserValuesNotification((values) => {
            respond(constants.MSG_NAME_PUSH_DATA, values)
        })

        // accept messages from the SERP and forward them to native
        window.addEventListener(constants.MSG_NAME_PROXY_INCOMING, (evt) => {
            try {
                assertCustomEvent(evt);
                if (evt.detail.kind === constants.MSG_NAME_SET_VALUES) {
                    this.setUserValues(evt.detail.data)
                        .then(updated => respond(constants.MSG_NAME_PUSH_DATA, updated))
                        .catch(console.error)
                }
                if (evt.detail.kind === constants.MSG_NAME_READ_VALUES) {
                    this.readUserValues()
                        .then(updated => respond(constants.MSG_NAME_PUSH_DATA, updated))
                        .catch(console.error)
                }
            } catch (e) {
                console.warn('cannot handle this message', e);
            }
        })
    }

    /**
     * @param {WebkitMessagingConfig} input
     * @returns {Communications}
     */
    static fromInjectedConfig(input) {
        const opts = new WebkitMessagingConfig(input)
        const messaging = new Messaging(opts);
        return new Communications(messaging, {
            updateStrategy: opts.hasModernWebkitAPI
                ? "window-method"
                : "polling"
        });
    }
}

/**
 * @param {any} event
 * @returns {asserts event is CustomEvent<{kind: string, data: any}>}
 */
function assertCustomEvent(event) {
    if (!('detail' in event)) throw new Error('none-custom event')
    if (typeof event.detail.kind !== "string") throw new Error('custom event requires detail.kind to be a string')
}

export class Pixel {
    /**
     * A list of known pixels
     * @param {{name: "overlay"} | {name: "play.use", remember: "0" | "1"} | {name: "play.do_not_use", remember: "0" | "1"}} input
     */
    constructor(input) {
        this.input = input
    }

    name() {
        return this.input.name
    }
    params() {
        switch (this.input.name) {
            case "overlay": return {}
            case "play.use":
            case "play.do_not_use": {
                return { remember: this.input.remember }
            }
            default: throw new Error('unreachable')
        }
    }
}