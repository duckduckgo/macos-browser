(function () {
    if (CREDENTIALS_ENABLED) {
        init();
    }
    function init() {
        const script = document.createElement('script')
        script.textContent = 'window.navigator.credentials = {get: () => {return Promise.reject()}}'
        const el = document.head || document.documentElement
        el.appendChild(script)
        el.remove()
    }
})()
