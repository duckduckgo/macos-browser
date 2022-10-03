export const macOSCommunications = {
    /**
     * Inform the native layer that an interaction occurred
     * @param {import("../youtube-inject.js").UserValues["privatePlayerMode"]} privatePlayerMode
     * @returns {Promise<never>|Promise<unknown | void>}
     */
    setUserValues(privatePlayerMode) {
        /** @type {import('../youtube-inject.js').UserValues} */
        const payload = {
            privatePlayerMode,
            overlayInteracted: true
        }
        console.log("📤 [outgoing]", payload);
        // @ts-ignore
        let resp = window.webkit?.messageHandlers?.setUserValues?.postMessage(payload);
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