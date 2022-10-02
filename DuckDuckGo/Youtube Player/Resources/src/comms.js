export const macOSCommunications = {
    /**
     * Inform the native layer that an interaction occurred
     * @param {import("../youtube-inject.js").UserValues["privatePlayerMode"]} privatePlayerMode
     * @returns {Promise<never>|Promise<unknown | void>}
     */
    setInteracted(privatePlayerMode) {
        /** @type {import('../youtube-inject.js').UserValues} */
        const payload = {
            privatePlayerMode,
            overlayInteracted: true
        }
        console.log("📤 [outgoing]", payload);
        // @ts-ignore
        let resp = window.webkit?.messageHandlers?.setInteracted?.postMessage(payload);
        if (resp instanceof Promise) {
            return resp.catch(e => console.error("could not call setInteracted", e));
        }
        return Promise.reject(resp)
    }
}