if (window.location.host !== 'duckduckgo.com') {
    document.addEventListener('wheel', (event) => {
        if (event.deltaX <= -1 && event.deltaY === 0) {
            event.preventDefault();
            window.webkit.messageHandlers.swipeBack.postMessage(true);
        }

        if (event.deltaX > 1 && event.deltaY === 0) {
            window.webkit.messageHandlers.swipeForward.postMessage(true);
        }
    });
}
