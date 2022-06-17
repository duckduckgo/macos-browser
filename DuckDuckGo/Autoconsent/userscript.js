import AutoConsent from '@duckduckgo/autoconsent';
import jsonRules from '@duckduckgo/autoconsent/rules/rules.json';

const autoconsent = new AutoConsent(
    window.webkit.messageHandlers.contentMessageHandler.postMessage,
    {
        enabled: true,
        autoAction: 'optOut',
        disabledCmps: [],
        enablePrehide: true,
    },
    jsonRules,
);
window.autoconsentMessageCallback = autoconsent.receiveMessageCallback;
