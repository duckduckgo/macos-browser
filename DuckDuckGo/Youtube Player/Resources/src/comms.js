export const macOSCommunications = {
    /**
     * Inform the native layer that an interaction occurred
     * @param {import("../youtube-inject.js").UserValues} userValues
     * @returns {Promise<never>|Promise<unknown | void>}
     */
    setUserValues(userValues) {
        console.log("📤 [outgoing]", userValues);
        // @ts-ignore
        let resp = window.webkit?.messageHandlers?.setUserValues?.postMessage(userValues);
        if (resp instanceof Promise) {
            return resp
                .then(x => JSON.parse(x))
                .catch(e => console.error("could not call setInteracted", e));
        }
        return Promise.reject(resp)
    },
    readUserValues() {
        // @ts-ignore
        let resp = window.webkit?.messageHandlers?.readUserValues?.postMessage({});
        if (resp instanceof Promise) {
            return resp
                .then(x => JSON.parse(x))
                .catch(e => console.error("could not call readUserValues", e));
        }
        return Promise.reject(resp)
    }
}
