import {WebkitMessagingConfig, Messaging} from "@duckduckgo/content-scope-utils/lib/messaging.js";

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
        return this.messaging.request('setUserValues', userValues)
    }
    async readUserValues() {
        return this.messaging.request('readUserValues', {})
    }

    /**
     * @param {Pixel} pixel
     */
    sendPixel(pixel) {
        this.messaging.notify('sendDuckPlayerPixel', {
            pixelName: pixel.name(),
            params: pixel.params()
        })
    }
    openInDuckPlayerViaMessage(href) {
        return this.messaging.notify('openDuckPlayer', {href})
    }
    /**
     * Get notification when preferences/state changed
     * @param cb
     * @param {import("../youtube-inject.js").UserValues} initialUserValues
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
            window.onUserValuesChanged = function(values) {
                if (!values?.userValuesNotification) {
                    console.error("missing userValuesNotification");
                    return;
                }
                cb(values.userValuesNotification)
            }
        }
        if (this.options.updateStrategy === "polling") {
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