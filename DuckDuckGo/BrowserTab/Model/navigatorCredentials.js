(function () {
    function getTopLevelURL () {
        try {
            // FROM: https://stackoverflow.com/a/7739035/73479
            // FIX: Better capturing of top level URL so that trackers in embedded documents are not considered first party
            return new URL(window.location !== window.parent.location ? document.referrer : document.location.href)
        } catch (error) {
            return new URL(location.href)
        }
    }

    const topLevelUrl = getTopLevelURL()
    let unprotectedDomain = false
    const domainParts = topLevelUrl && topLevelUrl.host ? topLevelUrl.host.split('.') : []
    // walk up the domain to see if it's unprotected
    while (domainParts.length > 1 && !unprotectedDomain) {
        const partialDomain = domainParts.join('.')
        unprotectedDomain = `
        CREDENTIALS_EXCEPTIONS
        `.split('\n').filter(domain => domain.trim() === partialDomain).length > 0
        domainParts.shift()
    }

    if (!unprotectedDomain && topLevelUrl.host != null) {
        unprotectedDomain = `
          USER_UNPROTECTED_DOMAINS
          `.split('\n').filter(domain => domain.trim() === topLevelUrl.host).length > 0
    }

    if (!unprotectedDomain) {
        init();
    }
    function init() {
        const script = document.createElement('script')
        script.textContent = `(() => {
            const value = {
                get() {
                    return Promise.reject()
                }
            }
            Object.defineProperty(Navigator.prototype, 'credentials', {
                value,
                configurable: true,
                enumerable: true
            })
        })()`
        const el = document.head || document.documentElement
        el.appendChild(script)
        script.remove()
    }
})()
