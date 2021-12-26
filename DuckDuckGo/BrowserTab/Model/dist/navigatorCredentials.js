(function () {
    'use strict';

    (function () {
        const featureList = userScriptUtils.parseNewLineList(`
    $CREDENTIALS_EXCEPTIONS$
    `);

        const userList = userScriptUtils.parseNewLineList(`
    $USER_UNPROTECTED_DOMAINS$
    `);

        if (!userScriptUtils.isUnprotectedDomain(featureList, userList)) {
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
