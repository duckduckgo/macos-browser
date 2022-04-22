/* global browser */
import AutoConsent from '@duckduckgo/autoconsent/lib/web'
import * as rules from '@duckduckgo/autoconsent/rules/rules.json'

const consent = new AutoConsent(browser, browser.tabs.sendMessage)

async function loadRules () {
    console.log(rules)
    Object.keys(rules.consentomatic).forEach((name) => {
        consent.addConsentomaticCMP(name, rules.consentomatic[name])
    })
    rules.autoconsent.forEach((rule) => {
        consent.addCMP(rule)
    })
    console.log('rules loaded', consent.rules.length);
}

loadRules()

browser.webNavigation.onCommitted.addListener((details) => {
    if (details.frameId === 0) {
        console.log('Received onCommitted, removing tab', details.tabId)
        consent.removeTab(details.tabId)
    }
}, {
    url: [{ schemes: ['http', 'https'] }]
})

browser.webNavigation.onCompleted.addListener(
    (args) => {
        console.log('Received onCompleted, running onFrame()', args);
        return consent.onFrame(args);
    }, {
        url: [{ schemes: ['http', 'https'] }]
    }
)

window.autoconsent = consent

window.callAction = (messageId, tabId, action) => {
    const respond = (obj) => {
        window.webkit.messageHandlers.actionResponse.postMessage(JSON.stringify({
            messageId,
            ...obj
        })).catch(() => console.warn('Error sending response', messageId, obj))
    }
    const errorResponse = (err) => {
        console.warn('action error', err)
        respond({ result: false, error: err.toString() })
    }

    if (action === 'detectCMP') {
        console.log(`detecting cmp for tab ${tabId}`);
        consent.checkTab(tabId).then(async (cmp) => {
            try {
                await cmp.checked
                console.log('cmp detection finished', cmp.getCMPName());
                respond({
                    ruleName: cmp.getCMPName(),
                    result: cmp.getCMPName() !== null
                })
            } catch (e) {
                errorResponse(e)
            }
        }, errorResponse)
    } else {
        const cmp = consent.tabCmps.get(tabId)
        if (!cmp) {
            respond({
                result: false
            })
            return
        }
        const successResponse = (result) => respond({ ruleName: cmp.getCMPName(), result })
        switch (action) {
        case 'detectPopup':
            // give up after (20 * 200) ms
            cmp.isPopupOpen(20, 200).then(successResponse, errorResponse)
            break
        case 'doOptOut':
            cmp.doOptOut().then(successResponse, errorResponse)
            break
        case 'selfTest':
            if (!cmp.hasTest()) {
                errorResponse('no test for this CMP')
            } else {
                cmp.testOptOutWorked().then(successResponse, errorResponse)
            }
            break
        }
    }
    return messageId
}
