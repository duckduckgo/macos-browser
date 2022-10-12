import {WebkitMessaging, WebkitMessagingConfig} from "./utils/WebkitMessaging.js";

export class MacOSCommunications {
    /** @type {WebkitMessaging} */
    messaging;
    /**
     * @param {WebkitMessaging} messaging
     */
    constructor(messaging) {
        this.messaging = messaging;
    }
    /**
     * Inform the native layer that an interaction occurred
     * @param {import("../youtube-inject.js").UserValues} userValues
     * @returns {Promise<import("../youtube-inject").UserValues>}
     */
    async setUserValues(userValues) {
        return this.messaging.wkSendAndWait('setUserValues', userValues)
    }
    async readUserValues() {
        return this.messaging.wkSendAndWait('readUserValues', {})
    }
    openInDuckPlayerViaMessage(href) {
        return this.messaging.wkSend('openDuckPlayer', href)
    }
    /**
     * Get notification when preferences/state changed
     * @param cb
     * @param {import("../youtube-inject.js").UserValues} initialUserValues
     */
    onUserValuesNotification(cb, initialUserValues) {
        if (this.messaging.config.hasModernWebkitAPI) {
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
        } else {
            /**
             * But on macOS < 11 (Catalina) we need to poll the native side to receive
             * notifications of any preferences changes
             */
            let timeout;
            let prevMode = Object.keys(initialUserValues.privatePlayerMode)?.[0];
            let prevInteracted = initialUserValues.overlayInteracted;
            const poll = () => {
                clearTimeout(timeout)
                timeout = setTimeout(async () => {
                    this.readUserValues()
                        .then(userValues => {
                            let nextMode = Object.keys(userValues.privatePlayerMode)?.[0];
                            let nextInteracted = userValues.overlayInteracted;
                            if (nextMode !== prevMode || nextInteracted !== prevInteracted) {
                                prevMode = nextMode
                                prevInteracted = nextInteracted
                                cb(userValues)
                            }
                            poll()
                        })
                        .catch(() => {
                            // noop on error
                        })
                }, 1000);
            }
            poll();
        }
    }

    /**
     * @param {WebkitMessagingConfig} input
     * @returns {MacOSCommunications}
     */
    static fromInjectedConfig(input) {
        const opts = new WebkitMessagingConfig(
            input.hasModernWebkitAPI,
            input.webkitMessageHandlerNames,
            input.secret,
        )
        const webkit = new WebkitMessaging(opts);
        return new MacOSCommunications(webkit);
    }
}

