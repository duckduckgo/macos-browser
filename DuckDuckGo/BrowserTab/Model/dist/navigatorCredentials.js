(function () {
    'use strict';

    function getTopLevelURL () {
        try {
            // FROM: https://stackoverflow.com/a/7739035/73479
            // FIX: Better capturing of top level URL so that trackers in embedded documents are not considered first party
            if (window.location !== window.parent.location) {
                return new URL(window.location.href !== 'about:blank' ? document.referrer : window.parent.location.href)
            } else {
                return new URL(window.location.href)
            }
        } catch (error) {
            return new URL(location.href)
        }
    }

    function parseNewLineList (stringVal) {
        return stringVal.split('\n').map(v => v.trim())
    }

    function isUnprotectedDomain (featureList, userList) {
        let unprotectedDomain = false;
        const topLevelUrl = getTopLevelURL();
        const domainParts = topLevelUrl && topLevelUrl.host ? topLevelUrl.host.split('.') : [];

        // walk up the domain to see if it's unprotected
        while (domainParts.length > 1 && !unprotectedDomain) {
            const partialDomain = domainParts.join('.');

            unprotectedDomain = featureList.filter(domain => domain === partialDomain).length > 0;

            domainParts.shift();
        }

        if (!unprotectedDomain && topLevelUrl.host != null) {
            unprotectedDomain = userList.filter(domain => domain === topLevelUrl.host).length > 0;
        }
        return unprotectedDomain
    }

    (function () {
        const featureList = parseNewLineList(`
    $CREDENTIALS_EXCEPTIONS$
    `);

        const userList = parseNewLineList(`
    $USER_UNPROTECTED_DOMAINS$
    `);

        if (!isUnprotectedDomain(featureList, userList)) {
            init();
        }
        function init () {
            const script = document.createElement('script');
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
        })()`;
            const el = document.head || document.documentElement;
            el.appendChild(script);
            script.remove();
        }
    })();

})();
