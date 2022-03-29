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
}

loadRules()

browser.webNavigation.onCommitted.addListener((details) => {
    url: [{ schemes: ['http', 'https'] }]
})

browser.webNavigation.onCompleted.addListener(consent.onFrame.bind(consent), {
    url: [{ schemes: ['http', 'https'] }]
})

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
        consent.removeTab(tabId);

        consent.checkTab(tabId).then(async (cmp) => {
            try {
                await cmp.checked
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
            cmp.isPopupOpen(20, 100).then(successResponse, errorResponse)
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
