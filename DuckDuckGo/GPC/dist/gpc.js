import { isUnprotectedDomain, parseNewLineList } from './userScriptUtils.js'

(function () {
    'use strict';

    const gpcEnabled = $GPC_ENABLED$;
    
    const featureList = parseNewLineList(`
        $GPC_EXCEPTIONS$
    `);
    const userList = parseNewLineList(`
        $USER_UNPROTECTED_DOMAINS$
    `);

    if (!gpcEnabled || isUnprotectedDomain(featureList, userList)) {
        return
    }

    const scriptContent = `
    if (navigator.globalPrivacyControl === undefined) {
        Object.defineProperty(Navigator.prototype, 'globalPrivacyControl', {
            get: () => true,
            configurable: true,
            enumerable: true
        });
    } else {
        try {
            navigator.globalPrivacyControl = true;
        } catch (e) {
            console.error('globalPrivacyControl is not writable: ', e);
        }
    }
    `;

    const e = document.createElement('script');
    e.textContent = scriptContent;
    (document.head || document.documentElement).appendChild(e);
    e.remove();

})();
