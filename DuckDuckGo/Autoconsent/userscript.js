import AutoConsent from '@duckduckgo/autoconsent';

const autoconsent = new AutoConsent(
    (message) => {
        console.log('sending', message);
        window.webkit.messageHandlers[message.type].postMessage(message).then(resp => {
            console.log('received', resp);
            autoconsent.receiveMessageCallback(resp);
        });
    },
);
