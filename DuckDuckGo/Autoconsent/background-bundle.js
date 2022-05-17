(function () {
    'use strict';

    const enableLogs = false; // change this to enable debug logs

    /* eslint-disable no-restricted-syntax,no-await-in-loop,no-underscore-dangle */
    async function waitFor(predicate, maxTimes, interval) {
        let result = await predicate();
        if (!result && maxTimes > 0) {
            return new Promise((resolve) => {
                setTimeout(async () => {
                    resolve(waitFor(predicate, maxTimes - 1, interval));
                }, interval);
            });
        }
        return Promise.resolve(result);
    }
    async function success(action) {
        const result = await action;
        if (!result) {
            throw new Error(`Action failed: ${action} ${result}`);
        }
        return result;
    }
    class AutoConsentBase {
        constructor(name) {
            this.hasSelfTest = true;
            this.name = name;
        }
        detectCmp(tab) {
            throw new Error('Not Implemented');
        }
        async detectPopup(tab) {
            return false;
        }
        detectFrame(tab, frame) {
            return false;
        }
        optOut(tab) {
            throw new Error('Not Implemented');
        }
        optIn(tab) {
            throw new Error('Not Implemented');
        }
        openCmp(tab) {
            throw new Error('Not Implemented');
        }
        async test(tab) {
            // try IAB by default
            return Promise.resolve(true);
        }
    }
    async function evaluateRule(rule, tab) {
        if (rule.frame && !tab.frame) {
            await waitFor(() => Promise.resolve(!!tab.frame), 10, 500);
        }
        const frameId = rule.frame && tab.frame ? tab.frame.id : undefined;
        const results = [];
        if (rule.exists) {
            results.push(tab.elementExists(rule.exists, frameId));
        }
        if (rule.visible) {
            results.push(tab.elementsAreVisible(rule.visible, rule.check, frameId));
        }
        if (rule.eval) {
            results.push(new Promise(async (resolve) => {
                // catch eval error silently
                try {
                    resolve(await tab.eval(rule.eval, frameId));
                }
                catch (e) {
                    resolve(false);
                }
            }));
        }
        if (rule.waitFor) {
            results.push(tab.waitForElement(rule.waitFor, rule.timeout || 10000, frameId));
        }
        if (rule.click) {
            if (rule.all === true) {
                results.push(tab.clickElements(rule.click, frameId));
            }
            else {
                results.push(tab.clickElement(rule.click, frameId));
            }
        }
        if (rule.waitForThenClick) {
            results.push(tab.waitForElement(rule.waitForThenClick, rule.timeout || 10000, frameId)
                .then(() => tab.clickElement(rule.waitForThenClick, frameId)));
        }
        if (rule.wait) {
            results.push(tab.wait(rule.wait));
        }
        if (rule.goto) {
            results.push(tab.goto(rule.goto));
        }
        if (rule.hide) {
            results.push(tab.hideElements(rule.hide, frameId));
        }
        if (rule.undoHide) {
            results.push(tab.undoHideElements(frameId));
        }
        if (rule.waitForFrame) {
            results.push(waitFor(() => !!tab.frame, 40, 500));
        }
        // boolean and of results
        return (await Promise.all(results)).reduce((a, b) => a && b, true);
    }
    class AutoConsent$1 extends AutoConsentBase {
        constructor(config) {
            super(config.name);
            this.config = config;
        }
        get prehideSelectors() {
            return this.config.prehideSelectors;
        }
        get isHidingRule() {
            return this.config.isHidingRule;
        }
        async _runRulesParallel(tab, rules) {
            const detections = await Promise.all(rules.map(rule => evaluateRule(rule, tab)));
            return detections.every(r => !!r);
        }
        async _runRulesSequentially(tab, rules) {
            for (const rule of rules) {
                const result = await evaluateRule(rule, tab);
                if (!result && !rule.optional) {
                    return false;
                }
            }
            return true;
        }
        async detectCmp(tab) {
            if (this.config.detectCmp) {
                return this._runRulesParallel(tab, this.config.detectCmp);
            }
            return false;
        }
        async detectPopup(tab) {
            if (this.config.detectPopup) {
                return this._runRulesParallel(tab, this.config.detectPopup);
            }
            return false;
        }
        detectFrame(tab, frame) {
            if (this.config.frame) {
                return frame.url.startsWith(this.config.frame);
            }
            return false;
        }
        async optOut(tab) {
            if (this.config.optOut) {
                return this._runRulesSequentially(tab, this.config.optOut);
            }
            return false;
        }
        async optIn(tab) {
            if (this.config.optIn) {
                return this._runRulesSequentially(tab, this.config.optIn);
            }
            return false;
        }
        async openCmp(tab) {
            if (this.config.openCmp) {
                return this._runRulesSequentially(tab, this.config.openCmp);
            }
            return false;
        }
        async test(tab) {
            if (this.config.test) {
                return this._runRulesSequentially(tab, this.config.test);
            }
            return super.test(tab);
        }
    }

    class TabActions {
        constructor(tabId, frame, sendContentMessage, browser) {
            this.frame = frame;
            this.sendContentMessage = sendContentMessage;
            this.browser = browser;
            this.id = tabId;
        }
        async elementExists(selector, frameId = 0) {
            return this.sendContentMessage(this.id, {
                type: "elemExists",
                selector
            }, {
                frameId
            });
        }
        async clickElement(selector, frameId = 0) {
            return this.sendContentMessage(this.id, {
                type: "click",
                selector
            }, {
                frameId
            });
        }
        async clickElements(selector, frameId = 0) {
            return this.sendContentMessage(this.id, {
                type: "click",
                all: true,
                selector
            }, {
                frameId
            });
        }
        async elementsAreVisible(selector, check, frameId = 0) {
            return this.sendContentMessage(this.id, {
                type: "elemVisible",
                selector,
                check
            }, {
                frameId
            });
        }
        async getAttribute(selector, attribute, frameId = 0) {
            return this.sendContentMessage(this.id, {
                type: "getAttribute",
                selector,
                attribute
            }, { frameId });
        }
        async eval(script, frameId = 0) {
            // console.log(`run ${script} in tab ${this.id}`);
            return await this.sendContentMessage(this.id, {
                type: "eval",
                script
            }, { frameId });
        }
        async waitForElement(selector, timeout, frameId = 0) {
            const interval = 200;
            const times = Math.ceil(timeout / interval);
            return waitFor(() => this.elementExists(selector, frameId), times, interval);
        }
        async waitForThenClick(selector, timeout, frameId = 0) {
            if (await this.waitForElement(selector, timeout, frameId)) {
                return await this.clickElement(selector, frameId);
            }
            return false;
        }
        async hideElements(selectors, frameId = 0, method = 'display') {
            return this.sendContentMessage(this.id, {
                type: "hide",
                selectors,
                method,
            }, { frameId });
        }
        async undoHideElements(frameId = 0) {
            return this.sendContentMessage(this.id, {
                type: "undohide",
            }, { frameId });
        }
        async getBrowserTab() {
            return this.browser.tabs.get(this.id);
        }
        async goto(url) {
            return this.browser.tabs.update(this.id, { url });
        }
        wait(ms) {
            return new Promise(resolve => {
                setTimeout(() => {
                    resolve(true);
                }, ms);
            });
        }
        matches(matcherConfig) {
            return this.sendContentMessage(this.id, {
                type: "matches",
                config: matcherConfig
            }, { frameId: 0 });
        }
        executeAction(config, param) {
            return this.sendContentMessage(this.id, {
                type: "executeAction",
                config,
                param
            }, { frameId: 0 });
        }
    }

    Promise.resolve(null);

    class TabConsent {
        constructor(tab, ruleCheckPromise) {
            this.tab = tab;
            this.optOutStatus = null;
            this.checked = ruleCheckPromise;
            ruleCheckPromise.then(rule => this.rule = rule);
        }
        getCMPName() {
            if (this.rule) {
                return this.rule.name;
            }
            return null;
        }
        async isPopupOpen(retries = 1, interval = 1000) {
            const isOpen = await this.rule.detectPopup(this.tab);
            if (!isOpen && retries > 0) {
                return new Promise((resolve) => setTimeout(() => resolve(this.isPopupOpen(retries - 1, interval)), interval));
            }
            return isOpen;
        }
        async doOptOut() {
            try {
                enableLogs && console.log(`doing opt out ${this.getCMPName()} in tab ${this.tab.id}`);
                this.optOutStatus = await this.rule.optOut(this.tab);
                return this.optOutStatus;
            }
            catch (e) {
                console.error('error during opt out', e);
                this.optOutStatus = e;
                throw e;
            }
            finally {
                if (!this.rule.isHidingRule) {
                    if (this.getCMPName().startsWith('com_')) {
                        this.tab.wait(5000).then(() => this.tab.undoHideElements());
                    }
                    else {
                        await this.tab.undoHideElements();
                    }
                }
            }
        }
        async doOptIn() {
            try {
                return this.rule.optIn(this.tab);
            }
            finally {
                if (!this.rule.isHidingRule) {
                    await this.tab.undoHideElements();
                }
            }
        }
        hasTest() {
            return !!this.rule.hasSelfTest;
        }
        async testOptOutWorked() {
            return this.rule.test(this.tab);
        }
        async applyCosmetics(selectors) {
            const hidden = await this.tab.hideElements(selectors);
            return hidden;
        }
    }

    async function detectDialog(tab, retries, rules) {
        let breakEarly = false;
        const found = await new Promise(async (resolve) => {
            let earlyReturn = false;
            await Promise.all(rules.map(async (r, index) => {
                try {
                    if (await r.detectCmp(tab)) {
                        earlyReturn = true;
                        enableLogs && console.log(`Found CMP in [${tab.id}]: ${r.name}`);
                        resolve(index);
                    }
                }
                catch (e) {
                    breakEarly = true;
                }
            }));
            if (!earlyReturn) {
                resolve(-1);
            }
        });
        if (found === -1 && retries > 0 && !breakEarly) {
            return new Promise((resolve) => {
                setTimeout(async () => {
                    const result = detectDialog(tab, retries - 1, rules);
                    resolve(result);
                }, 500);
            });
        }
        return found > -1 ? rules[found] : null;
    }

    class TrustArc extends AutoConsentBase {
        constructor() {
            super("TrustArc");
            this.prehideSelectors = [
                ".trustarc-banner-container",
                ".truste_popframe,.truste_overlay,.truste_box_overlay,#truste-consent-track",
            ];
        }
        detectFrame(_, frame) {
            return frame.url.startsWith("https://consent-pref.trustarc.com/?");
        }
        async detectCmp(tab) {
            if (tab.frame &&
                tab.frame.url.startsWith("https://consent-pref.trustarc.com/?")) {
                return true;
            }
            return tab.elementExists("#truste-show-consent");
        }
        async detectPopup(tab) {
            return ((await tab.elementsAreVisible("#truste-consent-content,#trustarc-banner-overlay")) ||
                (tab.frame &&
                    (await tab.waitForElement("#defaultpreferencemanager", 5000, tab.frame.id))));
        }
        async openFrame(tab) {
            if (await tab.elementExists("#truste-show-consent")) {
                await tab.clickElement("#truste-show-consent");
            }
        }
        async navigateToSettings(tab, frameId) {
            // wait for it to load
            await waitFor(async () => {
                return ((await tab.elementExists(".shp", frameId)) ||
                    (await tab.elementsAreVisible(".advance", "any", frameId)) ||
                    tab.elementExists(".switch span:first-child", frameId));
            }, 10, 500);
            // splash screen -> hit more information
            if (await tab.elementExists(".shp", frameId)) {
                await tab.clickElement(".shp", frameId);
            }
            await tab.waitForElement(".prefPanel", 5000, frameId);
            // go to advanced settings if not yet shown
            if (await tab.elementsAreVisible(".advance", "any", frameId)) {
                await tab.clickElement(".advance", frameId);
            }
            // takes a while to load the opt-in/opt-out buttons
            return await waitFor(() => tab.elementsAreVisible(".switch span:first-child", "any", frameId), 5, 1000);
        }
        async optOut(tab) {
            // await tab.hideElements(['.truste_overlay', '.truste_box_overlay', '.trustarc-banner', '.truste-banner']);
            if (await tab.elementExists("#truste-consent-required")) {
                return tab.clickElement("#truste-consent-required");
            }
            if (!tab.frame) {
                await tab.clickElement("#truste-show-consent");
                await waitFor(async () => !!tab.frame &&
                    (await tab.elementsAreVisible(".mainContent", "any", tab.frame.id)), 50, 100);
            }
            const frameId = tab.frame.id;
            await waitFor(() => tab.eval("document.readyState === 'complete'", frameId), 20, 100);
            tab.hideElements([".truste_popframe", ".truste_overlay", ".truste_box_overlay", "#truste-consent-track"]);
            if (await tab.elementExists('.rejectAll', frameId)) {
                return tab.clickElement('.rejectAll', frameId);
            }
            if (await tab.waitForElement('#catDetails0', 1000, frameId)) {
                await tab.clickElement("#catDetails0", frameId);
                return tab.clickElement(".submit", frameId);
            }
            if (await tab.elementExists(".required", frameId)) {
                await tab.clickElement(".required", frameId);
            }
            else {
                await this.navigateToSettings(tab, frameId);
                await tab.clickElements(".switch span:nth-child(1):not(.active)", frameId);
                await tab.clickElement(".submit", frameId);
            }
            try {
                await tab.waitForThenClick("#gwt-debug-close_id", 20000, tab.frame.id);
            }
            catch (e) {
                // ignore frame disappearing
            }
            return true;
        }
        async optIn(tab) {
            if (!tab.frame) {
                await this.openFrame(tab);
                await waitFor(() => !!tab.frame, 10, 200);
            }
            const frameId = tab.frame.id;
            await this.navigateToSettings(tab, frameId);
            await tab.clickElements(".switch span:nth-child(2)", frameId);
            await tab.clickElement(".submit", frameId);
            await waitFor(() => tab.elementExists("#gwt-debug-close_id", frameId), 300, 1000);
            await tab.clickElement("#gwt-debug-close_id", frameId);
            return true;
        }
        async openCmp(tab) {
            await tab.eval("truste.eu.clickListener()");
            return true;
        }
        async test() {
            // TODO: find out how to test TrustArc
            return true;
        }
    }

    class Cookiebot extends AutoConsentBase {
        constructor() {
            super('Cybotcookiebot');
            this.prehideSelectors = ["#CybotCookiebotDialog,#dtcookie-container,#cookiebanner"];
        }
        async detectCmp(tab) {
            try {
                return await tab.eval('typeof window.CookieConsent === "object" && typeof window.CookieConsent.name === "string"');
            }
            catch (e) {
                return false;
            }
        }
        detectPopup(tab) {
            return tab.elementExists('#CybotCookiebotDialog,#dtcookie-container,#cookiebanner');
        }
        async optOut(tab) {
            if (await tab.elementExists('.cookie-alert-extended-detail-link')) {
                await tab.clickElement('.cookie-alert-extended-detail-link');
                await tab.waitForElement('.cookie-alert-configuration', 1000);
                await tab.clickElements('.cookie-alert-configuration-input:checked');
                return tab.clickElement('.cookie-alert-extended-button-secondary');
            }
            if (await tab.elementExists('#dtcookie-container')) {
                return tab.clickElement('.h-dtcookie-decline');
            }
            if (await tab.elementExists('.cookiebot__button--settings')) {
                await tab.clickElement('.cookiebot__button--settings');
            }
            if (await tab.elementsAreVisible('#CybotCookiebotDialogBodyButtonDecline', 'all')) {
                return await tab.clickElement('#CybotCookiebotDialogBodyButtonDecline');
            }
            if (await tab.elementExists('.cookiebanner__link--details')) {
                await tab.clickElement('.cookiebanner__link--details');
            }
            await tab.clickElements('.CybotCookiebotDialogBodyLevelButton:checked:enabled,input[id*="CybotCookiebotDialogBodyLevelButton"]:checked:enabled');
            if (await tab.elementExists('#CybotCookiebotDialogBodyButtonDecline')) {
                await tab.clickElement('#CybotCookiebotDialogBodyButtonDecline');
            }
            if (await tab.elementExists('input[id^=CybotCookiebotDialogBodyLevelButton]:checked')) {
                await tab.clickElements('input[id^=CybotCookiebotDialogBodyLevelButton]:checked');
            }
            if (await tab.elementExists('#CybotCookiebotDialogBodyButtonAcceptSelected')) {
                await tab.clickElement('#CybotCookiebotDialogBodyButtonAcceptSelected');
            }
            else {
                await tab.clickElements('#CybotCookiebotDialogBodyLevelButtonAccept,#CybotCookiebotDialogBodyButtonAccept,#CybotCookiebotDialogBodyLevelButtonLevelOptinAllowallSelection');
            }
            // some sites have custom submit buttons with no obvious selectors. In this case we just call the submitConsent API.
            if (await tab.eval('CookieConsent.hasResponse !== true')) {
                await tab.eval('Cookiebot.dialog.submitConsent() || true');
                await tab.wait(500);
            }
            return true;
        }
        async optIn(tab) {
            if (await tab.elementExists('#dtcookie-container')) {
                return tab.clickElement('.h-dtcookie-accept');
            }
            await tab.clickElements('.CybotCookiebotDialogBodyLevelButton:not(:checked):enabled');
            await tab.clickElement('#CybotCookiebotDialogBodyLevelButtonAccept');
            await tab.clickElement('#CybotCookiebotDialogBodyButtonAccept');
            return true;
        }
        async openCmp(tab) {
            await tab.eval('CookieConsent.renew() || true');
            return tab.waitForElement('#CybotCookiebotDialog', 10000);
        }
        async test(tab) {
            return tab.eval('CookieConsent.declined === true');
        }
    }

    class SourcePoint extends AutoConsentBase {
        constructor() {
            super("Sourcepoint");
            this.ccpaMode = false;
            this.prehideSelectors = ["div[id^='sp_message_container_'],.message-overlay"];
        }
        detectFrame(_, frame) {
            try {
                const url = new URL(frame.url);
                if (url.searchParams.has('message_id') && url.hostname === 'ccpa-notice.sp-prod.net') {
                    this.ccpaMode = true;
                    return true;
                }
                return (url.pathname === '/index.html' || url.pathname === '/privacy-manager/index.html')
                    && url.searchParams.has('message_id') && url.searchParams.has('requestUUID');
            }
            catch (e) {
                return false;
            }
        }
        async detectCmp(tab) {
            return await tab.elementExists("div[id^='sp_message_container_']") || !!tab.frame;
        }
        async detectPopup(tab) {
            return await tab.elementsAreVisible("div[id^='sp_message_container_']");
        }
        async optIn(tab) {
            return tab.clickElement(".sp_choice_type_11", tab.frame.id);
        }
        isManagerOpen(tab) {
            return tab.frame && new URL(tab.frame.url).pathname === "/privacy-manager/index.html";
        }
        async optOut(tab) {
            try {
                tab.hideElements(["div[id^='sp_message_container_']"]);
                if (!this.isManagerOpen(tab)) {
                    if (!await waitFor(() => !!tab.frame, 30, 100)) {
                        throw "Frame never opened";
                    }
                    if (!await tab.elementExists("button.sp_choice_type_12", tab.frame.id)) {
                        // do not sell button
                        return tab.clickElement('button.sp_choice_type_13', tab.frame.id);
                    }
                    await success(tab.clickElement("button.sp_choice_type_12", tab.frame.id));
                    await waitFor(() => new URL(tab.frame.url).pathname === "/privacy-manager/index.html", 200, 100);
                }
                await tab.waitForElement('.type-modal', 20000, tab.frame.id);
                // reject all button is offered by some sites
                try {
                    const path = await Promise.race([
                        tab.waitForElement('.sp_choice_type_REJECT_ALL', 2000, tab.frame.id).then(r => 0),
                        tab.waitForElement('.reject-toggle', 2000, tab.frame.id).then(() => 1),
                        tab.waitForElement('.pm-features', 2000, tab.frame.id).then(r => 2),
                    ]);
                    if (path === 0) {
                        await tab.wait(1000);
                        return await success(tab.clickElement('.sp_choice_type_REJECT_ALL', tab.frame.id));
                    }
                    else if (path === 1) {
                        await tab.clickElement('.reject-toggle', tab.frame.id);
                    }
                    else {
                        await tab.waitForElement('.pm-features', 10000, tab.frame.id);
                        await tab.clickElements('.checked > span', tab.frame.id);
                        if (await tab.elementExists('.chevron', tab.frame.id)) {
                            await tab.clickElement('.chevron', tab.frame.id);
                        }
                    }
                }
                catch (e) { }
                return await tab.clickElement('.sp_choice_type_SAVE_AND_EXIT', tab.frame.id);
            }
            finally {
                tab.undoHideElements();
            }
        }
        async test(tab) {
            await tab.eval("__tcfapi('getTCData', 2, r => window.__rcsResult = r)");
            return tab.eval("Object.values(window.__rcsResult.purpose.consents).every(c => !c)");
        }
    }

    // Note: JS API is also available:
    // https://help.consentmanager.net/books/cmp/page/javascript-api
    class ConsentManager extends AutoConsentBase {
        constructor() {
            super("consentmanager.net");
            this.prehideSelectors = ["#cmpbox,#cmpbox2"];
        }
        detectCmp(tab) {
            return tab.elementExists("#cmpbox");
        }
        detectPopup(tab) {
            return tab.elementsAreVisible("#cmpbox .cmpmore", "any");
        }
        async optOut(tab) {
            if (await tab.elementExists(".cmpboxbtnno")) {
                return tab.clickElement(".cmpboxbtnno");
            }
            if (await tab.elementExists(".cmpwelcomeprpsbtn")) {
                await tab.clickElements(".cmpwelcomeprpsbtn > a[aria-checked=true]");
                return await tab.clickElement(".cmpboxbtnsave");
            }
            await tab.clickElement(".cmpboxbtncustom");
            await tab.waitForElement(".cmptblbox", 2000);
            await tab.clickElements(".cmptdchoice > a[aria-checked=true]");
            return tab.clickElement(".cmpboxbtnyescustomchoices");
        }
        async optIn(tab) {
            return tab.clickElement(".cmpboxbtnyes");
        }
    }

    // Note: JS API is also available:
    // https://help.consentmanager.net/books/cmp/page/javascript-api
    class Evidon extends AutoConsentBase {
        constructor() {
            super("Evidon");
        }
        detectCmp(tab) {
            return tab.elementExists("#_evidon_banner");
        }
        detectPopup(tab) {
            return tab.elementsAreVisible("#_evidon_banner");
        }
        async optOut(tab) {
            if (await tab.elementExists("#_evidon-decline-button")) {
                return tab.clickElement("#_evidon-decline-button");
            }
            tab.hideElements(["#evidon-prefdiag-overlay", "#evidon-prefdiag-background"]);
            await tab.clickElement("#_evidon-option-button");
            await tab.waitForElement("#evidon-prefdiag-overlay", 5000);
            return tab.clickElement("#evidon-prefdiag-decline");
        }
        async optIn(tab) {
            return tab.clickElement("#_evidon-accept-button");
        }
    }

    class Onetrust extends AutoConsentBase {
        constructor() {
            super("Onetrust");
            this.prehideSelectors = ["#onetrust-banner-sdk,#onetrust-consent-sdk,.optanon-alert-box-wrapper,.onetrust-pc-dark-filter,.js-consent-banner"];
        }
        detectCmp(tab) {
            return tab.elementExists("#onetrust-banner-sdk,.optanon-alert-box-wrapper");
        }
        detectPopup(tab) {
            return tab.elementsAreVisible("#onetrust-banner-sdk,.optanon-alert-box-wrapper");
        }
        async optOut(tab) {
            if (await tab.elementExists("#onetrust-pc-btn-handler")) { // "show purposes" button inside a popup
                await success(tab.clickElement("#onetrust-pc-btn-handler"));
            }
            else { // otherwise look for a generic "show settings" button
                await success(tab.clickElement(".ot-sdk-show-settings,button.js-cookie-settings"));
            }
            await success(tab.waitForElement("#onetrust-consent-sdk", 2000));
            await success(tab.wait(1000));
            await tab.clickElements("#onetrust-consent-sdk input.category-switch-handler:checked,.js-editor-toggle-state:checked"); // optional step
            await success(tab.waitForThenClick(".save-preference-btn-handler,.js-consent-save", 1000));
            // popup doesn't disappear immediately
            await waitFor(async () => !(await tab.elementsAreVisible("#onetrust-banner-sdk")), 10, 500);
            return true;
        }
        async optIn(tab) {
            return tab.clickElement("onetrust-accept-btn-handler,js-accept-cookies");
        }
        async test(tab) {
            return tab.eval("window.OnetrustActiveGroups.split(',').filter(s => s.length > 0).length <= 1");
        }
    }

    const rules$3 = [
        new TrustArc(),
        new Cookiebot(),
        new SourcePoint(),
        new ConsentManager(),
        new Evidon(),
        new Onetrust(),
    ];
    function createAutoCMP(config) {
        return new AutoConsent$1(config);
    }

    const rules$2 = rules$3;

    class ConsentOMaticCMP {
        constructor(name, config) {
            this.name = name;
            this.config = config;
            this.methods = new Map();
            config.methods.forEach(methodConfig => {
                if (methodConfig.action) {
                    this.methods.set(methodConfig.name, methodConfig.action);
                }
            });
            this.hasSelfTest = this.methods.has("TEST_CONSENT");
        }
        async detectCmp(tab) {
            return (await Promise.all(this.config.detectors.map(detectorConfig => tab.matches(detectorConfig.presentMatcher)))).some(matched => matched);
        }
        async detectPopup(tab) {
            return (await Promise.all(this.config.detectors.map(detectorConfig => tab.matches(detectorConfig.showingMatcher)))).some(matched => matched);
        }
        async executeAction(tab, method, param) {
            if (this.methods.has(method)) {
                return tab.executeAction(this.methods.get(method), param);
            }
            return true;
        }
        async optOut(tab) {
            await this.executeAction(tab, "HIDE_CMP");
            await this.executeAction(tab, "OPEN_OPTIONS");
            await this.executeAction(tab, "HIDE_CMP");
            await this.executeAction(tab, "DO_CONSENT", []);
            await this.executeAction(tab, "SAVE_CONSENT");
            return true;
        }
        async optIn(tab) {
            await this.executeAction(tab, "HIDE_CMP");
            await this.executeAction(tab, "OPEN_OPTIONS");
            await this.executeAction(tab, "HIDE_CMP");
            await this.executeAction(tab, "DO_CONSENT", ['D', 'A', 'B', 'E', 'F', 'X']);
            await this.executeAction(tab, "SAVE_CONSENT");
            return true;
        }
        async openCmp(tab) {
            await this.executeAction(tab, "HIDE_CMP");
            await this.executeAction(tab, "OPEN_OPTIONS");
            return true;
        }
        test(tab) {
            return this.executeAction(tab, "TEST_CONSENT");
        }
        detectFrame(tab, frame) {
            return false;
        }
    }

    // hide rules not specific to a single CMP rule
    const globalHidden = [
        "#didomi-popup,.didomi-popup-container,.didomi-popup-notice,.didomi-consent-popup-preferences,#didomi-notice,.didomi-popup-backdrop,.didomi-screen-medium",
    ];
    async function prehideElements(tab, rules) {
        const selectors = rules.reduce((selectorList, rule) => {
            if (rule.prehideSelectors) {
                return [...selectorList, ...rule.prehideSelectors];
            }
            return selectorList;
        }, globalHidden);
        await tab.hideElements(selectors, undefined, 'opacity');
    }

    class AutoConsent {
        constructor(browser, sendContentMessage) {
            this.browser = browser;
            this.sendContentMessage = sendContentMessage;
            this.consentFrames = new Map();
            this.tabCmps = new Map();
            this.sendContentMessage = sendContentMessage;
            this.rules = [...rules$2];
        }
        addCMP(config) {
            this.rules.push(createAutoCMP(config));
        }
        disableCMPs(cmpNames) {
            this.rules = this.rules.filter((cmp) => !cmpNames.includes(cmp.name));
        }
        addConsentomaticCMP(name, config) {
            this.rules.push(new ConsentOMaticCMP(`com_${name}`, config));
        }
        createTab(tabId) {
            return new TabActions(tabId, this.consentFrames.get(tabId), this.sendContentMessage, this.browser);
        }
        async checkTab(tabId, prehide = true) {
            const tab = this.createTab(tabId);
            if (prehide) {
                this.prehideElements(tab);
            }
            const consent = new TabConsent(tab, this.detectDialog(tab, 20));
            this.tabCmps.set(tabId, consent);
            // check tabs
            consent.checked.then((rule) => {
                if (this.consentFrames.has(tabId) && rule) {
                    const frame = this.consentFrames.get(tabId);
                    if (frame.type === rule.name) {
                        consent.tab.frame = frame;
                    }
                }
                // no CMP detected, undo hiding
                if (!rule && prehide) {
                    tab.undoHideElements();
                }
            });
            return this.tabCmps.get(tabId);
        }
        removeTab(tabId) {
            this.tabCmps.delete(tabId);
            this.consentFrames.delete(tabId);
        }
        onFrame({ tabId, url, frameId }) {
            // ignore main frames
            if (frameId === 0) {
                return;
            }
            try {
                const frame = {
                    id: frameId,
                    url: url,
                };
                const tab = this.createTab(tabId);
                const frameMatch = this.rules.findIndex(r => r.detectFrame(tab, frame));
                if (frameMatch > -1) {
                    this.consentFrames.set(tabId, {
                        type: this.rules[frameMatch].name,
                        url,
                        id: frameId,
                    });
                    if (this.tabCmps.has(tabId)) {
                        this.tabCmps.get(tabId).tab.frame = this.consentFrames.get(tabId);
                    }
                }
            }
            catch (e) {
                console.error(e);
            }
        }
        async detectDialog(tab, retries) {
            return detectDialog(tab, retries, this.rules);
        }
        async prehideElements(tab) {
            return prehideElements(tab, this.rules);
        }
    }

    var autoconsent = [
    	{
    		name: "arzt-auskunft.de",
    		prehideSelectors: [
    			"#cookiescript_injected"
    		],
    		detectCmp: [
    			{
    				exists: "#cookiescript_injected"
    			}
    		],
    		detectPopup: [
    			{
    				visible: "#cookiescript_injected"
    			}
    		],
    		optOut: [
    			{
    				click: "#cookiescript_reject"
    			}
    		],
    		optIn: [
    			{
    				click: "#cookiescript_accept"
    			}
    		]
    	},
    	{
    		name: "asus",
    		detectCmp: [
    			{
    				exists: "#cookie-policy-info"
    			}
    		],
    		detectPopup: [
    			{
    				visible: "#cookie-policy-info"
    			}
    		],
    		optIn: [
    			{
    				click: ".btn-read-ck"
    			}
    		],
    		optOut: [
    			{
    				click: ".btn-setting"
    			},
    			{
    				click: ".btn-save"
    			}
    		]
    	},
    	{
    		name: "aws.amazon.com",
    		prehideSelectors: [
    			"#awsccc-cb-content",
    			"#awsccc-cs-container",
    			"#awsccc-cs-modalOverlay",
    			"#awsccc-cs-container-inner"
    		],
    		detectCmp: [
    			{
    				exists: "#awsccc-cb-content"
    			}
    		],
    		detectPopup: [
    			{
    				visible: "#awsccc-cb-content"
    			}
    		],
    		optIn: [
    			{
    				click: "button[data-id=awsccc-cb-btn-accept"
    			}
    		],
    		optOut: [
    			{
    				click: "button[data-id=awsccc-cb-btn-customize]"
    			},
    			{
    				"eval": "Array.from(document.querySelectorAll('input[aria-checked=true')).forEach(e => e.click()) || true"
    			},
    			{
    				click: "button[data-id=awsccc-cs-btn-save]"
    			}
    		]
    	},
    	{
    		name: "baden-wuerttemberg.de",
    		isHidingRule: true,
    		prehideSelectors: [
    			".cookie-alert.t-dark"
    		],
    		detectCmp: [
    			{
    				exists: ".cookie-alert.t-dark"
    			}
    		],
    		detectPopup: [
    			{
    				visible: ".cookie-alert.t-dark"
    			}
    		],
    		optIn: [
    			{
    				click: ".cookie-alert__button"
    			}
    		],
    		optOut: [
    		]
    	},
    	{
    		name: "borlabs",
    		prehideSelectors: [
    			"#BorlabsCookieBox"
    		],
    		detectCmp: [
    			{
    				exists: "._brlbs-block-content"
    			}
    		],
    		detectPopup: [
    			{
    				visible: "._brlbs-bar-wrap,._brlbs-box-wrap"
    			}
    		],
    		optIn: [
    			{
    				click: "a[data-cookie-accept-all]"
    			}
    		],
    		optOut: [
    			{
    				click: "a[data-cookie-refuse]"
    			}
    		]
    	},
    	{
    		name: "bundesregierung.de",
    		prehideSelectors: [
    			".bpa-cookie-banner"
    		],
    		detectCmp: [
    			{
    				exists: ".bpa-cookie-banner"
    			}
    		],
    		detectPopup: [
    			{
    				visible: ".bpa-cookie-banner .bpa-module-full-hero"
    			}
    		],
    		optIn: [
    			{
    				click: ".bpa-accept-all-button"
    			}
    		],
    		optOut: [
    			{
    				click: ".bpa-close-button"
    			}
    		],
    		test: [
    			{
    				"eval": "document.cookie.match('cookie-allow-tracking=0')"
    			}
    		]
    	},
    	{
    		name: "cc_banner",
    		prehideSelectors: [
    			".cc_banner-wrapper"
    		],
    		isHidingRule: true,
    		detectCmp: [
    			{
    				exists: ".cc_banner-wrapper"
    			}
    		],
    		detectPopup: [
    			{
    				visible: ".cc_banner"
    			}
    		],
    		optIn: [
    			{
    				click: ".cc_btn_accept_all"
    			}
    		],
    		optOut: [
    			{
    				hide: [
    					".cc_banner-wrapper"
    				]
    			}
    		]
    	},
    	{
    		name: "cookie-law-info",
    		prehideSelectors: [
    			"#cookie-law-info-bar"
    		],
    		detectCmp: [
    			{
    				exists: "#cookie-law-info-bar"
    			}
    		],
    		detectPopup: [
    			{
    				visible: "#cookie-law-info-bar"
    			}
    		],
    		optIn: [
    			{
    				click: "[data-cli_action=\"accept\"]"
    			}
    		],
    		optOut: [
    			{
    				hide: [
    					"#cookie-law-info-bar"
    				]
    			},
    			{
    				"eval": "CLI.disableAllCookies() || CLI.reject_close() || true"
    			}
    		],
    		test: [
    			{
    				"eval": "document.cookie.indexOf('cookielawinfo-checkbox-non-necessary=yes') === -1"
    			}
    		]
    	},
    	{
    		name: "cookie-notice",
    		prehideSelectors: [
    			"#cookie-notice"
    		],
    		isHidingRule: true,
    		detectCmp: [
    			{
    				exists: "#cookie-notice"
    			}
    		],
    		detectPopup: [
    			{
    				visible: "#cookie-notice"
    			}
    		],
    		optIn: [
    			{
    				hide: [
    					"#cn-accept-cookie"
    				]
    			}
    		],
    		optOut: [
    			{
    				hide: [
    					"#cookie-notice"
    				]
    			}
    		]
    	},
    	{
    		name: "cookieconsent",
    		prehideSelectors: [
    			"[aria-label=\"cookieconsent\"]"
    		],
    		isHidingRule: true,
    		detectCmp: [
    			{
    				exists: "[aria-label=\"cookieconsent\"]"
    			}
    		],
    		detectPopup: [
    			{
    				visible: "[aria-label=\"cookieconsent\"]"
    			}
    		],
    		optIn: [
    			{
    				click: ".cc-dismiss"
    			}
    		],
    		optOut: [
    			{
    				hide: [
    					"[aria-label=\"cookieconsent\"]"
    				]
    			}
    		]
    	},
    	{
    		name: "corona-in-zahlen.de",
    		prehideSelectors: [
    			".cookiealert"
    		],
    		detectCmp: [
    			{
    				exists: ".cookiealert"
    			}
    		],
    		detectPopup: [
    			{
    				visible: ".cookiealert"
    			}
    		],
    		optOut: [
    			{
    				click: ".configurecookies"
    			},
    			{
    				click: ".confirmcookies"
    			}
    		],
    		optIn: [
    			{
    				click: ".acceptcookies"
    			}
    		]
    	},
    	{
    		name: "deepl.com",
    		prehideSelectors: [
    			".dl_cookieBanner_container"
    		],
    		detectCmp: [
    			{
    				exists: ".dl_cookieBanner_container"
    			}
    		],
    		detectPopup: [
    			{
    				visible: ".dl_cookieBanner_container"
    			}
    		],
    		optOut: [
    			{
    				click: ".dl_cookieBanner--buttonSelected"
    			}
    		],
    		optIn: [
    			{
    				click: ".dl_cookieBanner--buttonAll"
    			}
    		]
    	},
    	{
    		name: "destatis.de",
    		prehideSelectors: [
    			"div[aria-labelledby=cookiebannerhead]"
    		],
    		isHidingRule: true,
    		detectCmp: [
    			{
    				exists: ".cookiebannerbox"
    			}
    		],
    		detectPopup: [
    			{
    				visible: ".cookiebannerbox"
    			}
    		],
    		optOut: [
    			{
    				hide: [
    					".cookiebannerbox"
    				]
    			}
    		]
    	},
    	{
    		name: "Drupal",
    		detectCmp: [
    			{
    				exists: "#drupalorg-crosssite-gdpr"
    			}
    		],
    		detectPopup: [
    			{
    				visible: "#drupalorg-crosssite-gdpr"
    			}
    		],
    		optOut: [
    			{
    				click: ".no"
    			}
    		],
    		optIn: [
    			{
    				click: ".yes"
    			}
    		]
    	},
    	{
    		name: "etsy",
    		detectCmp: [
    			{
    				exists: "#gdpr-single-choice-overlay"
    			}
    		],
    		detectPopup: [
    			{
    				visible: "#gdpr-single-choice-overlay"
    			}
    		],
    		optOut: [
    			{
    				hide: [
    					"#gdpr-single-choice-overlay",
    					"#gdpr-privacy-settings"
    				]
    			},
    			{
    				click: "button[data-gdpr-open-full-settings]"
    			},
    			{
    				wait: 500
    			},
    			{
    				"eval": "document.querySelectorAll('.gdpr-overlay-body input').forEach(toggle => { toggle.checked = false; }) || true"
    			},
    			{
    				"eval": "document.querySelector('.gdpr-overlay-view button[data-wt-overlay-close]').click() || true"
    			}
    		],
    		optIn: [
    			{
    				click: "button[data-gdpr-single-choice-accept]"
    			}
    		]
    	},
    	{
    		name: "eu-cookie-compliance-banner",
    		isHidingRule: true,
    		detectCmp: [
    			{
    				exists: ".eu-cookie-compliance-banner-info"
    			}
    		],
    		detectPopup: [
    			{
    				visible: ".eu-cookie-compliance-banner-info"
    			}
    		],
    		optIn: [
    			{
    				click: ".agree-button"
    			}
    		],
    		optOut: [
    			{
    				click: ".decline-button,.eu-cookie-compliance-save-preferences-button",
    				optional: true
    			},
    			{
    				hide: [
    					".eu-cookie-compliance-banner-info",
    					"#sliding-popup"
    				]
    			}
    		],
    		test: [
    			{
    				"eval": "document.cookie.indexOf('cookie-agreed=2') === -1"
    			}
    		]
    	},
    	{
    		name: "funding-choices",
    		prehideSelectors: [
    			".fc-consent-root,.fc-dialog-container,.fc-dialog-overlay,.fc-dialog-content"
    		],
    		detectCmp: [
    			{
    				exists: ".fc-consent-root"
    			}
    		],
    		detectPopup: [
    			{
    				exists: ".fc-dialog-container"
    			}
    		],
    		optOut: [
    			{
    				click: ".fc-cta-do-not-consent,.fc-cta-manage-options"
    			},
    			{
    				click: ".fc-preference-consent:checked,.fc-preference-legitimate-interest:checked",
    				all: true,
    				optional: true
    			},
    			{
    				click: ".fc-confirm-choices",
    				optional: true
    			}
    		],
    		optIn: [
    			{
    				click: ".fc-cta-consent"
    			}
    		]
    	},
    	{
    		name: "hl.co.uk",
    		prehideSelectors: [
    			".cookieModalContent",
    			"#cookie-banner-overlay"
    		],
    		detectCmp: [
    			{
    				exists: "#cookie-banner-overlay"
    			}
    		],
    		detectPopup: [
    			{
    				exists: "#cookie-banner-overlay"
    			}
    		],
    		optIn: [
    			{
    				click: "#acceptCookieButton"
    			}
    		],
    		optOut: [
    			{
    				click: "#manageCookie"
    			},
    			{
    				hide: [
    					".cookieSettingsModal"
    				]
    			},
    			{
    				wait: 500
    			},
    			{
    				click: "#AOCookieToggle"
    			},
    			{
    				"eval": "document.querySelector('#AOCookieToggle').getAttribute('aria-pressed') === 'false'"
    			},
    			{
    				click: "#TPCookieToggle"
    			},
    			{
    				"eval": "document.querySelector('#TPCookieToggle').getAttribute('aria-pressed') === 'false'"
    			},
    			{
    				click: "#updateCookieButton"
    			}
    		]
    	},
    	{
    		name: "hubspot",
    		detectCmp: [
    			{
    				exists: "#hs-eu-cookie-confirmation"
    			}
    		],
    		detectPopup: [
    			{
    				visible: "#hs-eu-cookie-confirmation"
    			}
    		],
    		optIn: [
    			{
    				click: "#hs-eu-confirmation-button"
    			}
    		],
    		optOut: [
    			{
    				click: "#hs-eu-decline-button"
    			}
    		]
    	},
    	{
    		name: "ionos.de",
    		prehideSelectors: [
    			".privacy-consent--backdrop",
    			".privacy-consent--modal"
    		],
    		detectCmp: [
    			{
    				exists: ".privacy-consent--modal"
    			}
    		],
    		detectPopup: [
    			{
    				visible: ".privacy-consent--modal"
    			}
    		],
    		optIn: [
    			{
    				click: "#selectAll"
    			}
    		],
    		optOut: [
    			{
    				click: ".footer-config-link"
    			},
    			{
    				click: "#confirmSelection"
    			}
    		]
    	},
    	{
    		name: "johnlewis.com",
    		prehideSelectors: [
    			"div[class^=pecr-cookie-banner-]"
    		],
    		detectCmp: [
    			{
    				exists: "div[class^=pecr-cookie-banner-]"
    			}
    		],
    		detectPopup: [
    			{
    				exists: "div[class^=pecr-cookie-banner-]"
    			}
    		],
    		optOut: [
    			{
    				click: "button[data-test^=manage-cookies]"
    			},
    			{
    				wait: "500"
    			},
    			{
    				"eval": "!!Array.from(document.querySelectorAll('label[data-test^=toggle]')).forEach(e => e.click())",
    				optional: true
    			},
    			{
    				"eval": "Array.from(document.querySelectorAll('label[data-test^=toggle]')).filter(e => e.className.match('checked') && !e.className.match('disabled')).length === 0"
    			},
    			{
    				click: "button[data-test=save-preferences]"
    			}
    		],
    		optIn: [
    			{
    				click: "button[data-test=allow-all]"
    			}
    		]
    	},
    	{
    		name: "klaro",
    		detectCmp: [
    			{
    				exists: ".klaro > .cookie-notice"
    			}
    		],
    		detectPopup: [
    			{
    				visible: ".klaro > .cookie-notice"
    			}
    		],
    		optIn: [
    			{
    				click: ".cm-btn-success"
    			}
    		],
    		optOut: [
    			{
    				click: ".cn-decline"
    			}
    		],
    		test: [
    			{
    				"eval": "Object.values(klaro.getManager().consents).every(c => !c)"
    			}
    		]
    	},
    	{
    		name: "mediamarkt.de",
    		prehideSelectors: [
    			"div[aria-labelledby=pwa-consent-layer-title]",
    			"div[class^=StyledConsentLayerWrapper-]"
    		],
    		detectCmp: [
    			{
    				exists: "div[aria-labelledby^=pwa-consent-layer-title]"
    			}
    		],
    		detectPopup: [
    			{
    				exists: "div[aria-labelledby^=pwa-consent-layer-title]"
    			}
    		],
    		optOut: [
    			{
    				click: "button[data-test^=pwa-consent-layer-deny-all]"
    			}
    		],
    		optIn: [
    			{
    				click: "'button[data-test^=pwa-consent-layer-accept-all'"
    			}
    		]
    	},
    	{
    		name: "metoffice.gov.uk",
    		prehideSelectors: [
    			"#ccc-module"
    		],
    		detectCmp: [
    			{
    				exists: "#ccc-module"
    			}
    		],
    		detectPopup: [
    			{
    				exists: "#ccc-module"
    			}
    		],
    		optOut: [
    			{
    				click: "#ccc-reject-settings"
    			}
    		],
    		optIn: [
    			{
    				click: "#ccc-recommended-settings"
    			}
    		]
    	},
    	{
    		name: "microsoft.com",
    		prehideSelectors: [
    			"#wcpConsentBannerCtrl"
    		],
    		detectCmp: [
    			{
    				exists: "#wcpConsentBannerCtrl"
    			}
    		],
    		detectPopup: [
    			{
    				exists: "#wcpConsentBannerCtrl"
    			}
    		],
    		optOut: [
    			{
    				"eval": "Array.from(document.querySelectorAll('div > button')).filter(el => el.innerText.match('Reject|Ablehnen'))[0].click() || true"
    			}
    		],
    		optIn: [
    			{
    				"eval": "Array.from(document.querySelectorAll('div > button')).filter(el => el.innerText.match('Accept|Annehmen'))[0].click()"
    			}
    		],
    		test: [
    			{
    				"eval": "!!document.cookie.match('MSCC')"
    			}
    		]
    	},
    	{
    		name: "moneysavingexpert.com",
    		detectCmp: [
    			{
    				exists: "dialog[data-testid=accept-our-cookies-dialog]"
    			}
    		],
    		detectPopup: [
    			{
    				visible: "dialog[data-testid=accept-our-cookies-dialog]"
    			}
    		],
    		optIn: [
    			{
    				click: "#banner-accept"
    			}
    		],
    		optOut: [
    			{
    				click: "#banner-manage"
    			},
    			{
    				click: "#pc-confirm"
    			}
    		]
    	},
    	{
    		name: "motor-talk.de",
    		prehideSelectors: [
    			".mt-cc-bnnr__wrapper"
    		],
    		detectCmp: [
    			{
    				exists: ".mt-cc-bnnr"
    			}
    		],
    		detectPopup: [
    			{
    				visible: ".mt-cc-bnnr__wrapper"
    			}
    		],
    		optIn: [
    			{
    				click: ".mt-cc-bnnr__button-main"
    			}
    		],
    		optOut: [
    			{
    				click: ".mt-cc-bnnr__decline-link"
    			}
    		]
    	},
    	{
    		name: "national-lottery.co.uk",
    		detectCmp: [
    			{
    				exists: ".cuk_cookie_consent"
    			}
    		],
    		detectPopup: [
    			{
    				visible: ".cuk_cookie_consent",
    				check: "any"
    			}
    		],
    		optOut: [
    			{
    				click: ".cuk_cookie_consent_manage_pref"
    			},
    			{
    				click: ".cuk_cookie_consent_save_pref"
    			},
    			{
    				click: ".cuk_cookie_consent_close"
    			}
    		],
    		optIn: [
    			{
    				click: ".cuk_cookie_consent_accept_all"
    			}
    		]
    	},
    	{
    		name: "netflix.de",
    		detectCmp: [
    			{
    				exists: "#cookie-disclosure"
    			}
    		],
    		detectPopup: [
    			{
    				visible: ".cookie-disclosure-message",
    				check: "any"
    			}
    		],
    		optIn: [
    			{
    				click: ".btn-accept"
    			}
    		],
    		optOut: [
    			{
    				hide: [
    					"#cookie-disclosure"
    				]
    			},
    			{
    				click: ".btn-reject"
    			}
    		]
    	},
    	{
    		name: "nhs.uk",
    		prehideSelectors: [
    			"#nhsuk-cookie-banner"
    		],
    		detectCmp: [
    			{
    				exists: "#nhsuk-cookie-banner"
    			}
    		],
    		detectPopup: [
    			{
    				exists: "#nhsuk-cookie-banner"
    			}
    		],
    		optOut: [
    			{
    				click: "#nhsuk-cookie-banner__link_accept"
    			}
    		],
    		optIn: [
    			{
    				click: "#nhsuk-cookie-banner__link_accept_analytics"
    			}
    		]
    	},
    	{
    		name: "notice-cookie",
    		prehideSelectors: [
    			".button--notice"
    		],
    		isHidingRule: true,
    		detectCmp: [
    			{
    				exists: ".notice--cookie"
    			}
    		],
    		detectPopup: [
    			{
    				visible: ".notice--cookie"
    			}
    		],
    		optIn: [
    			{
    				click: ".button--notice"
    			}
    		],
    		optOut: [
    			{
    				hide: [
    					".notice--cookie"
    				]
    			}
    		]
    	},
    	{
    		name: "obi.de",
    		prehideSelectors: [
    			".disc-cp--active"
    		],
    		detectCmp: [
    			{
    				exists: ".disc-cp-modal__modal"
    			}
    		],
    		detectPopup: [
    			{
    				visible: ".disc-cp-modal__modal"
    			}
    		],
    		optIn: [
    			{
    				click: ".js-disc-cp-accept-all"
    			}
    		],
    		optOut: [
    			{
    				click: ".js-disc-cp-deny-all"
    			}
    		]
    	},
    	{
    		name: "osano",
    		prehideSelectors: [
    			".osano-cm-window"
    		],
    		isHidingRule: true,
    		detectCmp: [
    			{
    				exists: ".osano-cm-window"
    			}
    		],
    		detectPopup: [
    			{
    				visible: ".osano-cm-dialog"
    			}
    		],
    		optIn: [
    			{
    				click: ".osano-cm-accept-all"
    			}
    		],
    		optOut: [
    			{
    				hide: [
    					".osano-cm-window"
    				]
    			}
    		]
    	},
    	{
    		name: "otto.de",
    		prehideSelectors: [
    			".cookieBanner--visibility"
    		],
    		detectCmp: [
    			{
    				exists: ".cookieBanner--visibility"
    			}
    		],
    		detectPopup: [
    			{
    				visible: ".cookieBanner__wrapper"
    			}
    		],
    		optIn: [
    			{
    				click: ".js_cookieBannerPermissionButton"
    			}
    		],
    		optOut: [
    			{
    				click: ".js_cookieBannerProhibitionButton"
    			}
    		]
    	},
    	{
    		name: "paypal.de",
    		prehideSelectors: [
    			"#gdprCookieBanner"
    		],
    		detectCmp: [
    			{
    				exists: "#gdprCookieBanner"
    			}
    		],
    		detectPopup: [
    			{
    				visible: "#gdprCookieContent_wrapper"
    			}
    		],
    		optIn: [
    			{
    				click: "#acceptAllButton"
    			}
    		],
    		optOut: [
    			{
    				click: ".gdprCookieBanner_decline-button"
    			}
    		]
    	},
    	{
    		name: "quantcast",
    		prehideSelectors: [
    			"#qc-cmp2-main,#qc-cmp2-container"
    		],
    		detectCmp: [
    			{
    				exists: "#qc-cmp2-container"
    			}
    		],
    		detectPopup: [
    			{
    				visible: "#qc-cmp2-ui"
    			}
    		],
    		optOut: [
    			{
    				click: ".qc-cmp2-summary-buttons > button[mode=\"secondary\"]"
    			},
    			{
    				waitFor: "#qc-cmp2-ui"
    			},
    			{
    				click: ".qc-cmp2-toggle-switch > button[aria-checked=\"true\"]",
    				all: true,
    				optional: true
    			},
    			{
    				click: ".qc-cmp2-main button[aria-label=\"REJECT ALL\"]",
    				optional: true
    			},
    			{
    				waitForThenClick: ".qc-cmp2-main button[aria-label=\"SAVE & EXIT\"],.qc-cmp2-buttons-desktop > button[mode=\"primary\"]",
    				timeout: 5000
    			}
    		],
    		optIn: [
    			{
    				click: ".qc-cmp2-summary-buttons > button[mode=\"primary\"]"
    			}
    		]
    	},
    	{
    		name: "snigel",
    		detectCmp: [
    			{
    				exists: ".snigel-cmp-framework"
    			}
    		],
    		detectPopup: [
    			{
    				visible: ".snigel-cmp-framework"
    			}
    		],
    		optOut: [
    			{
    				click: "#sn-b-custom"
    			},
    			{
    				click: "#sn-b-save"
    			}
    		],
    		test: [
    			{
    				"eval": "!!document.cookie.match('snconsent')"
    			}
    		]
    	},
    	{
    		name: "steampowered.com",
    		detectCmp: [
    			{
    				exists: ".cookiepreferences_popup"
    			},
    			{
    				visible: ".cookiepreferences_popup"
    			}
    		],
    		detectPopup: [
    			{
    				visible: ".cookiepreferences_popup"
    			}
    		],
    		optOut: [
    			{
    				click: "#rejectAllButton"
    			}
    		],
    		optIn: [
    			{
    				click: "#acceptAllButton"
    			}
    		],
    		test: [
    			{
    				wait: 1000
    			},
    			{
    				"eval": "JSON.parse(decodeURIComponent(document.cookie.split(';').find(s => s.trim().startsWith('cookieSettings')).split('=')[1])).preference_state === 2"
    			}
    		]
    	},
    	{
    		name: "Tealium",
    		prehideSelectors: [
    			"#__tealiumGDPRecModal,#__tealiumGDPRcpPrefs,#consent-layer"
    		],
    		isHidingRule: false,
    		detectCmp: [
    			{
    				exists: "#__tealiumGDPRecModal"
    			},
    			{
    				"eval": "window.utag && typeof utag.gdpr === 'object'"
    			}
    		],
    		detectPopup: [
    			{
    				visible: "#__tealiumGDPRecModal"
    			}
    		],
    		optOut: [
    			{
    				hide: [
    					"#__tealiumGDPRecModal",
    					"#__tealiumGDPRcpPrefs",
    					"#consent-layer"
    				]
    			},
    			{
    				click: "#cm-acceptNone,.js-accept-essential-cookies"
    			}
    		],
    		optIn: [
    			{
    				hide: [
    					"#__tealiumGDPRecModal"
    				]
    			},
    			{
    				"eval": "utag.gdpr.setConsentValue(true)"
    			}
    		],
    		test: [
    			{
    				"eval": "utag.gdpr.getConsentState() !== 1"
    			}
    		]
    	},
    	{
    		name: "Test page CMP",
    		prehideSelectors: [
    			"#reject-all"
    		],
    		detectCmp: [
    			{
    				exists: "#privacy-test-page-cmp-test"
    			}
    		],
    		detectPopup: [
    			{
    				visible: "#privacy-test-page-cmp-test"
    			}
    		],
    		optIn: [
    			{
    				click: "#accept-all"
    			}
    		],
    		optOut: [
    			{
    				waitFor: "#reject-all"
    			},
    			{
    				click: "#reject-all"
    			}
    		],
    		test: [
    			{
    				"eval": "window.results.results[0] === 'button_clicked'"
    			}
    		]
    	},
    	{
    		name: "thalia.de",
    		prehideSelectors: [
    			".consent-banner-box"
    		],
    		detectCmp: [
    			{
    				exists: "consent-banner[component=consent-banner]"
    			}
    		],
    		detectPopup: [
    			{
    				visible: ".consent-banner-box"
    			}
    		],
    		optIn: [
    			{
    				click: ".button-zustimmen"
    			}
    		],
    		optOut: [
    			{
    				click: "button[data-consent=disagree]"
    			}
    		]
    	},
    	{
    		name: "thefreedictionary.com",
    		prehideSelectors: [
    			"#cmpBanner"
    		],
    		detectCmp: [
    			{
    				exists: "#cmpBanner"
    			}
    		],
    		detectPopup: [
    			{
    				visible: "#cmpBanner"
    			}
    		],
    		optIn: [
    			{
    				"eval": "cmpUi.allowAll()"
    			}
    		],
    		optOut: [
    			{
    				"eval": "cmpUi.showPurposes() || cmpUi.rejectAll() || true"
    			}
    		]
    	},
    	{
    		name: "usercentrics-1",
    		detectCmp: [
    			{
    				exists: "#usercentrics-root"
    			}
    		],
    		detectPopup: [
    			{
    				"eval": "!!document.querySelector('#usercentrics-root').shadowRoot.querySelector('#uc-center-container')"
    			}
    		],
    		optIn: [
    			{
    				"eval": "!!UC_UI.acceptAllConsents()"
    			},
    			{
    				"eval": "!!UC_UI.closeCMP()"
    			},
    			{
    				"eval": "UC_UI.areAllConsentsAccepted() === true"
    			}
    		],
    		optOut: [
    			{
    				"eval": "!!UC_UI.closeCMP()"
    			},
    			{
    				"eval": "!!UC_UI.denyAllConsents()"
    			}
    		],
    		test: [
    			{
    				"eval": "UC_UI.areAllConsentsAccepted() === false"
    			}
    		]
    	},
    	{
    		name: "vodafone.de",
    		prehideSelectors: [
    			".dip-consent,.dip-consent-container"
    		],
    		detectCmp: [
    			{
    				exists: ".dip-consent-container"
    			}
    		],
    		detectPopup: [
    			{
    				visible: ".dip-consent-content"
    			}
    		],
    		optOut: [
    			{
    				click: ".dip-consent-btn.white-btn"
    			},
    			{
    				"eval": "Array.from(document.querySelectorAll('.dip-consent-btn.red-btn')).filter(e => e.innerText === 'Auswahl bestätigen')[0].click() || true"
    			}
    		],
    		optIn: [
    			{
    				click: ".dip-consent-btn.red-btn"
    			}
    		]
    	},
    	{
    		name: "xing.com",
    		detectCmp: [
    			{
    				exists: "div[class^=cookie-consent-CookieConsent]"
    			}
    		],
    		detectPopup: [
    			{
    				exists: "div[class^=cookie-consent-CookieConsent]"
    			}
    		],
    		optIn: [
    			{
    				click: "#consent-accept-button"
    			}
    		],
    		optOut: [
    			{
    				click: "#consent-settings-button"
    			},
    			{
    				click: ".consent-banner-button-accept-overlay"
    			}
    		],
    		test: [
    			{
    				"eval": "document.cookie.includes('userConsent=%7B%22marketing%22%3Afalse')"
    			}
    		]
    	}
    ];
    var consentomatic = {
    	"didomi.io": {
    		detectors: [
    			{
    				presentMatcher: {
    					target: {
    						selector: "#didomi-host, #didomi-notice"
    					},
    					type: "css"
    				},
    				showingMatcher: {
    					target: {
    						selector: "body.didomi-popup-open, .didomi-notice-banner"
    					},
    					type: "css"
    				}
    			}
    		],
    		methods: [
    			{
    				action: {
    					target: {
    						selector: ".didomi-popup-notice-buttons .didomi-button:not(.didomi-button-highlight), .didomi-notice-banner .didomi-learn-more-button"
    					},
    					type: "click"
    				},
    				name: "OPEN_OPTIONS"
    			},
    			{
    				action: {
    					actions: [
    						{
    							retries: 50,
    							target: {
    								selector: "#didomi-purpose-cookies"
    							},
    							type: "waitcss",
    							waitTime: 50
    						},
    						{
    							consents: [
    								{
    									description: "Share (everything) with others",
    									falseAction: {
    										target: {
    											selector: ".didomi-components-radio__option[aria-describedby=didomi-purpose-share_whith_others]:first-child"
    										},
    										type: "click"
    									},
    									trueAction: {
    										target: {
    											selector: ".didomi-components-radio__option[aria-describedby=didomi-purpose-share_whith_others]:last-child"
    										},
    										type: "click"
    									},
    									type: "X"
    								},
    								{
    									description: "Information storage and access",
    									falseAction: {
    										target: {
    											selector: ".didomi-components-radio__option[aria-describedby=didomi-purpose-cookies]:first-child"
    										},
    										type: "click"
    									},
    									trueAction: {
    										target: {
    											selector: ".didomi-components-radio__option[aria-describedby=didomi-purpose-cookies]:last-child"
    										},
    										type: "click"
    									},
    									type: "D"
    								},
    								{
    									description: "Content selection, offers and marketing",
    									falseAction: {
    										target: {
    											selector: ".didomi-components-radio__option[aria-describedby=didomi-purpose-CL-T1Rgm7]:first-child"
    										},
    										type: "click"
    									},
    									trueAction: {
    										target: {
    											selector: ".didomi-components-radio__option[aria-describedby=didomi-purpose-CL-T1Rgm7]:last-child"
    										},
    										type: "click"
    									},
    									type: "E"
    								},
    								{
    									description: "Analytics",
    									falseAction: {
    										target: {
    											selector: ".didomi-components-radio__option[aria-describedby=didomi-purpose-analytics]:first-child"
    										},
    										type: "click"
    									},
    									trueAction: {
    										target: {
    											selector: ".didomi-components-radio__option[aria-describedby=didomi-purpose-analytics]:last-child"
    										},
    										type: "click"
    									},
    									type: "B"
    								},
    								{
    									description: "Analytics",
    									falseAction: {
    										target: {
    											selector: ".didomi-components-radio__option[aria-describedby=didomi-purpose-M9NRHJe3G]:first-child"
    										},
    										type: "click"
    									},
    									trueAction: {
    										target: {
    											selector: ".didomi-components-radio__option[aria-describedby=didomi-purpose-M9NRHJe3G]:last-child"
    										},
    										type: "click"
    									},
    									type: "B"
    								},
    								{
    									description: "Ad and content selection",
    									falseAction: {
    										target: {
    											selector: ".didomi-components-radio__option[aria-describedby=didomi-purpose-advertising_personalization]:first-child"
    										},
    										type: "click"
    									},
    									trueAction: {
    										target: {
    											selector: ".didomi-components-radio__option[aria-describedby=didomi-purpose-advertising_personalization]:last-child"
    										},
    										type: "click"
    									},
    									type: "F"
    								},
    								{
    									description: "Ad and content selection",
    									falseAction: {
    										parent: {
    											childFilter: {
    												target: {
    													selector: "#didomi-purpose-pub-ciblee"
    												}
    											},
    											selector: ".didomi-consent-popup-data-processing, .didomi-components-accordion-label-container"
    										},
    										target: {
    											selector: ".didomi-components-radio__option[aria-describedby=didomi-purpose-pub-ciblee]:first-child"
    										},
    										type: "click"
    									},
    									trueAction: {
    										target: {
    											selector: ".didomi-components-radio__option[aria-describedby=didomi-purpose-pub-ciblee]:last-child"
    										},
    										type: "click"
    									},
    									type: "F"
    								},
    								{
    									description: "Ad and content selection - basics",
    									falseAction: {
    										target: {
    											selector: ".didomi-components-radio__option[aria-describedby=didomi-purpose-q4zlJqdcD]:first-child"
    										},
    										type: "click"
    									},
    									trueAction: {
    										target: {
    											selector: ".didomi-components-radio__option[aria-describedby=didomi-purpose-q4zlJqdcD]:last-child"
    										},
    										type: "click"
    									},
    									type: "F"
    								},
    								{
    									description: "Ad and content selection - partners and subsidiaries",
    									falseAction: {
    										target: {
    											selector: ".didomi-components-radio__option[aria-describedby=didomi-purpose-partenaire-cAsDe8jC]:first-child"
    										},
    										type: "click"
    									},
    									trueAction: {
    										target: {
    											selector: ".didomi-components-radio__option[aria-describedby=didomi-purpose-partenaire-cAsDe8jC]:last-child"
    										},
    										type: "click"
    									},
    									type: "F"
    								},
    								{
    									description: "Ad and content selection - social networks",
    									falseAction: {
    										target: {
    											selector: ".didomi-components-radio__option[aria-describedby=didomi-purpose-p4em9a8m]:first-child"
    										},
    										type: "click"
    									},
    									trueAction: {
    										target: {
    											selector: ".didomi-components-radio__option[aria-describedby=didomi-purpose-p4em9a8m]:last-child"
    										},
    										type: "click"
    									},
    									type: "F"
    								},
    								{
    									description: "Ad and content selection - others",
    									falseAction: {
    										target: {
    											selector: ".didomi-components-radio__option[aria-describedby=didomi-purpose-autres-pub]:first-child"
    										},
    										type: "click"
    									},
    									trueAction: {
    										target: {
    											selector: ".didomi-components-radio__option[aria-describedby=didomi-purpose-autres-pub]:last-child"
    										},
    										type: "click"
    									},
    									type: "F"
    								},
    								{
    									description: "Social networks",
    									falseAction: {
    										target: {
    											selector: ".didomi-components-radio__option[aria-describedby=didomi-purpose-reseauxsociaux]:first-child"
    										},
    										type: "click"
    									},
    									trueAction: {
    										target: {
    											selector: ".didomi-components-radio__option[aria-describedby=didomi-purpose-reseauxsociaux]:last-child"
    										},
    										type: "click"
    									},
    									type: "A"
    								},
    								{
    									description: "Social networks",
    									falseAction: {
    										target: {
    											selector: ".didomi-components-radio__option[aria-describedby=didomi-purpose-social_media]:first-child"
    										},
    										type: "click"
    									},
    									trueAction: {
    										target: {
    											selector: ".didomi-components-radio__option[aria-describedby=didomi-purpose-social_media]:last-child"
    										},
    										type: "click"
    									},
    									type: "A"
    								},
    								{
    									description: "Content selection",
    									falseAction: {
    										target: {
    											selector: ".didomi-components-radio__option[aria-describedby=didomi-purpose-content_personalization]:first-child"
    										},
    										type: "click"
    									},
    									trueAction: {
    										target: {
    											selector: ".didomi-components-radio__option[aria-describedby=didomi-purpose-content_personalization]:last-child"
    										},
    										type: "click"
    									},
    									type: "E"
    								},
    								{
    									description: "Ad delivery",
    									falseAction: {
    										target: {
    											selector: ".didomi-components-radio__option[aria-describedby=didomi-purpose-ad_delivery]:first-child"
    										},
    										type: "click"
    									},
    									trueAction: {
    										target: {
    											selector: ".didomi-components-radio__option[aria-describedby=didomi-purpose-ad_delivery]:last-child"
    										},
    										type: "click"
    									},
    									type: "F"
    								}
    							],
    							type: "consent"
    						},
    						{
    							action: {
    								consents: [
    									{
    										matcher: {
    											childFilter: {
    												target: {
    													selector: ":not(.didomi-components-radio__option--selected)"
    												}
    											},
    											type: "css"
    										},
    										trueAction: {
    											target: {
    												selector: ":nth-child(2)"
    											},
    											type: "click"
    										},
    										falseAction: {
    											target: {
    												selector: ":first-child"
    											},
    											type: "click"
    										},
    										type: "X"
    									}
    								],
    								type: "consent"
    							},
    							target: {
    								selector: ".didomi-components-radio"
    							},
    							type: "foreach"
    						}
    					],
    					type: "list"
    				},
    				name: "DO_CONSENT"
    			},
    			{
    				action: {
    					parent: {
    						selector: ".didomi-consent-popup-footer .didomi-consent-popup-actions"
    					},
    					target: {
    						selector: ".didomi-components-button:first-child"
    					},
    					type: "click"
    				},
    				name: "SAVE_CONSENT"
    			}
    		]
    	},
    	oil: {
    		detectors: [
    			{
    				presentMatcher: {
    					target: {
    						selector: ".as-oil-content-overlay"
    					},
    					type: "css"
    				},
    				showingMatcher: {
    					target: {
    						selector: ".as-oil-content-overlay"
    					},
    					type: "css"
    				}
    			}
    		],
    		methods: [
    			{
    				action: {
    					actions: [
    						{
    							target: {
    								selector: ".as-js-advanced-settings"
    							},
    							type: "click"
    						},
    						{
    							retries: "10",
    							target: {
    								selector: ".as-oil-cpc__purpose-container"
    							},
    							type: "waitcss",
    							waitTime: "250"
    						}
    					],
    					type: "list"
    				},
    				name: "OPEN_OPTIONS"
    			},
    			{
    				action: {
    					actions: [
    						{
    							consents: [
    								{
    									matcher: {
    										parent: {
    											selector: ".as-oil-cpc__purpose-container",
    											textFilter: [
    												"Information storage and access",
    												"Opbevaring af og adgang til oplysninger på din enhed"
    											]
    										},
    										target: {
    											selector: "input"
    										},
    										type: "checkbox"
    									},
    									toggleAction: {
    										parent: {
    											selector: ".as-oil-cpc__purpose-container",
    											textFilter: [
    												"Information storage and access",
    												"Opbevaring af og adgang til oplysninger på din enhed"
    											]
    										},
    										target: {
    											selector: ".as-oil-cpc__switch"
    										},
    										type: "click"
    									},
    									type: "D"
    								},
    								{
    									matcher: {
    										parent: {
    											selector: ".as-oil-cpc__purpose-container",
    											textFilter: [
    												"Personlige annoncer",
    												"Personalisation"
    											]
    										},
    										target: {
    											selector: "input"
    										},
    										type: "checkbox"
    									},
    									toggleAction: {
    										parent: {
    											selector: ".as-oil-cpc__purpose-container",
    											textFilter: [
    												"Personlige annoncer",
    												"Personalisation"
    											]
    										},
    										target: {
    											selector: ".as-oil-cpc__switch"
    										},
    										type: "click"
    									},
    									type: "E"
    								},
    								{
    									matcher: {
    										parent: {
    											selector: ".as-oil-cpc__purpose-container",
    											textFilter: [
    												"Annoncevalg, levering og rapportering",
    												"Ad selection, delivery, reporting"
    											]
    										},
    										target: {
    											selector: "input"
    										},
    										type: "checkbox"
    									},
    									toggleAction: {
    										parent: {
    											selector: ".as-oil-cpc__purpose-container",
    											textFilter: [
    												"Annoncevalg, levering og rapportering",
    												"Ad selection, delivery, reporting"
    											]
    										},
    										target: {
    											selector: ".as-oil-cpc__switch"
    										},
    										type: "click"
    									},
    									type: "F"
    								},
    								{
    									matcher: {
    										parent: {
    											selector: ".as-oil-cpc__purpose-container",
    											textFilter: [
    												"Personalisering af indhold",
    												"Content selection, delivery, reporting"
    											]
    										},
    										target: {
    											selector: "input"
    										},
    										type: "checkbox"
    									},
    									toggleAction: {
    										parent: {
    											selector: ".as-oil-cpc__purpose-container",
    											textFilter: [
    												"Personalisering af indhold",
    												"Content selection, delivery, reporting"
    											]
    										},
    										target: {
    											selector: ".as-oil-cpc__switch"
    										},
    										type: "click"
    									},
    									type: "E"
    								},
    								{
    									matcher: {
    										parent: {
    											childFilter: {
    												target: {
    													selector: ".as-oil-cpc__purpose-header",
    													textFilter: [
    														"Måling",
    														"Measurement"
    													]
    												}
    											},
    											selector: ".as-oil-cpc__purpose-container"
    										},
    										target: {
    											selector: "input"
    										},
    										type: "checkbox"
    									},
    									toggleAction: {
    										parent: {
    											childFilter: {
    												target: {
    													selector: ".as-oil-cpc__purpose-header",
    													textFilter: [
    														"Måling",
    														"Measurement"
    													]
    												}
    											},
    											selector: ".as-oil-cpc__purpose-container"
    										},
    										target: {
    											selector: ".as-oil-cpc__switch"
    										},
    										type: "click"
    									},
    									type: "B"
    								},
    								{
    									matcher: {
    										parent: {
    											selector: ".as-oil-cpc__purpose-container",
    											textFilter: "Google"
    										},
    										target: {
    											selector: "input"
    										},
    										type: "checkbox"
    									},
    									toggleAction: {
    										parent: {
    											selector: ".as-oil-cpc__purpose-container",
    											textFilter: "Google"
    										},
    										target: {
    											selector: ".as-oil-cpc__switch"
    										},
    										type: "click"
    									},
    									type: "F"
    								}
    							],
    							type: "consent"
    						}
    					],
    					type: "list"
    				},
    				name: "DO_CONSENT"
    			},
    			{
    				action: {
    					target: {
    						selector: ".as-oil__btn-optin"
    					},
    					type: "click"
    				},
    				name: "SAVE_CONSENT"
    			},
    			{
    				action: {
    					target: {
    						selector: "div.as-oil"
    					},
    					type: "hide"
    				},
    				name: "HIDE_CMP"
    			}
    		]
    	},
    	optanon: {
    		detectors: [
    			{
    				presentMatcher: {
    					target: {
    						selector: "#optanon-menu, .optanon-alert-box-wrapper"
    					},
    					type: "css"
    				},
    				showingMatcher: {
    					target: {
    						displayFilter: true,
    						selector: ".optanon-alert-box-wrapper"
    					},
    					type: "css"
    				}
    			}
    		],
    		methods: [
    			{
    				action: {
    					actions: [
    						{
    							target: {
    								selector: ".optanon-alert-box-wrapper .optanon-toggle-display, a[onclick*='OneTrust.ToggleInfoDisplay()'], a[onclick*='Optanon.ToggleInfoDisplay()']"
    							},
    							type: "click"
    						}
    					],
    					type: "list"
    				},
    				name: "OPEN_OPTIONS"
    			},
    			{
    				action: {
    					actions: [
    						{
    							target: {
    								selector: ".preference-menu-item #Your-privacy"
    							},
    							type: "click"
    						},
    						{
    							target: {
    								selector: "#optanon-vendor-consent-text"
    							},
    							type: "click"
    						},
    						{
    							action: {
    								consents: [
    									{
    										matcher: {
    											target: {
    												selector: "input"
    											},
    											type: "checkbox"
    										},
    										toggleAction: {
    											target: {
    												selector: "label"
    											},
    											type: "click"
    										},
    										type: "X"
    									}
    								],
    								type: "consent"
    							},
    							target: {
    								selector: "#optanon-vendor-consent-list .vendor-item"
    							},
    							type: "foreach"
    						},
    						{
    							target: {
    								selector: ".vendor-consent-back-link"
    							},
    							type: "click"
    						},
    						{
    							parent: {
    								selector: "#optanon-menu, .optanon-menu"
    							},
    							target: {
    								selector: ".menu-item-performance"
    							},
    							trueAction: {
    								actions: [
    									{
    										parent: {
    											selector: "#optanon-menu, .optanon-menu"
    										},
    										target: {
    											selector: ".menu-item-performance"
    										},
    										type: "click"
    									},
    									{
    										consents: [
    											{
    												matcher: {
    													parent: {
    														selector: "#optanon-popup-body-right"
    													},
    													target: {
    														selector: ".optanon-status input"
    													},
    													type: "checkbox"
    												},
    												toggleAction: {
    													parent: {
    														selector: "#optanon-popup-body-right"
    													},
    													target: {
    														selector: ".optanon-status label"
    													},
    													type: "click"
    												},
    												type: "B"
    											}
    										],
    										type: "consent"
    									}
    								],
    								type: "list"
    							},
    							type: "ifcss"
    						},
    						{
    							parent: {
    								selector: "#optanon-menu, .optanon-menu"
    							},
    							target: {
    								selector: ".menu-item-functional"
    							},
    							trueAction: {
    								actions: [
    									{
    										parent: {
    											selector: "#optanon-menu, .optanon-menu"
    										},
    										target: {
    											selector: ".menu-item-functional"
    										},
    										type: "click"
    									},
    									{
    										consents: [
    											{
    												matcher: {
    													parent: {
    														selector: "#optanon-popup-body-right"
    													},
    													target: {
    														selector: ".optanon-status input"
    													},
    													type: "checkbox"
    												},
    												toggleAction: {
    													parent: {
    														selector: "#optanon-popup-body-right"
    													},
    													target: {
    														selector: ".optanon-status label"
    													},
    													type: "click"
    												},
    												type: "E"
    											}
    										],
    										type: "consent"
    									}
    								],
    								type: "list"
    							},
    							type: "ifcss"
    						},
    						{
    							parent: {
    								selector: "#optanon-menu, .optanon-menu"
    							},
    							target: {
    								selector: ".menu-item-advertising"
    							},
    							trueAction: {
    								actions: [
    									{
    										parent: {
    											selector: "#optanon-menu, .optanon-menu"
    										},
    										target: {
    											selector: ".menu-item-advertising"
    										},
    										type: "click"
    									},
    									{
    										consents: [
    											{
    												matcher: {
    													parent: {
    														selector: "#optanon-popup-body-right"
    													},
    													target: {
    														selector: ".optanon-status input"
    													},
    													type: "checkbox"
    												},
    												toggleAction: {
    													parent: {
    														selector: "#optanon-popup-body-right"
    													},
    													target: {
    														selector: ".optanon-status label"
    													},
    													type: "click"
    												},
    												type: "F"
    											}
    										],
    										type: "consent"
    									}
    								],
    								type: "list"
    							},
    							type: "ifcss"
    						},
    						{
    							parent: {
    								selector: "#optanon-menu, .optanon-menu"
    							},
    							target: {
    								selector: ".menu-item-social"
    							},
    							trueAction: {
    								actions: [
    									{
    										parent: {
    											selector: "#optanon-menu, .optanon-menu"
    										},
    										target: {
    											selector: ".menu-item-social"
    										},
    										type: "click"
    									},
    									{
    										consents: [
    											{
    												matcher: {
    													parent: {
    														selector: "#optanon-popup-body-right"
    													},
    													target: {
    														selector: ".optanon-status input"
    													},
    													type: "checkbox"
    												},
    												toggleAction: {
    													parent: {
    														selector: "#optanon-popup-body-right"
    													},
    													target: {
    														selector: ".optanon-status label"
    													},
    													type: "click"
    												},
    												type: "B"
    											}
    										],
    										type: "consent"
    									}
    								],
    								type: "list"
    							},
    							type: "ifcss"
    						},
    						{
    							parent: {
    								selector: "#optanon-menu, .optanon-menu"
    							},
    							target: {
    								selector: ".menu-item-necessary",
    								textFilter: "Social Media Cookies"
    							},
    							trueAction: {
    								actions: [
    									{
    										parent: {
    											selector: "#optanon-menu, .optanon-menu"
    										},
    										target: {
    											selector: ".menu-item-necessary",
    											textFilter: "Social Media Cookies"
    										},
    										type: "click"
    									},
    									{
    										consents: [
    											{
    												matcher: {
    													parent: {
    														selector: "#optanon-popup-body-right"
    													},
    													target: {
    														selector: ".optanon-status input"
    													},
    													type: "checkbox"
    												},
    												toggleAction: {
    													parent: {
    														selector: "#optanon-popup-body-right"
    													},
    													target: {
    														selector: ".optanon-status label"
    													},
    													type: "click"
    												},
    												type: "B"
    											}
    										],
    										type: "consent"
    									}
    								],
    								type: "list"
    							},
    							type: "ifcss"
    						},
    						{
    							parent: {
    								selector: "#optanon-menu, .optanon-menu"
    							},
    							target: {
    								selector: ".menu-item-necessary",
    								textFilter: "Personalisation"
    							},
    							trueAction: {
    								actions: [
    									{
    										parent: {
    											selector: "#optanon-menu, .optanon-menu"
    										},
    										target: {
    											selector: ".menu-item-necessary",
    											textFilter: "Personalisation"
    										},
    										type: "click"
    									},
    									{
    										consents: [
    											{
    												matcher: {
    													parent: {
    														selector: "#optanon-popup-body-right"
    													},
    													target: {
    														selector: ".optanon-status input"
    													},
    													type: "checkbox"
    												},
    												toggleAction: {
    													parent: {
    														selector: "#optanon-popup-body-right"
    													},
    													target: {
    														selector: ".optanon-status label"
    													},
    													type: "click"
    												},
    												type: "E"
    											}
    										],
    										type: "consent"
    									}
    								],
    								type: "list"
    							},
    							type: "ifcss"
    						},
    						{
    							parent: {
    								selector: "#optanon-menu, .optanon-menu"
    							},
    							target: {
    								selector: ".menu-item-necessary",
    								textFilter: "Site monitoring cookies"
    							},
    							trueAction: {
    								actions: [
    									{
    										parent: {
    											selector: "#optanon-menu, .optanon-menu"
    										},
    										target: {
    											selector: ".menu-item-necessary",
    											textFilter: "Site monitoring cookies"
    										},
    										type: "click"
    									},
    									{
    										consents: [
    											{
    												matcher: {
    													parent: {
    														selector: "#optanon-popup-body-right"
    													},
    													target: {
    														selector: ".optanon-status input"
    													},
    													type: "checkbox"
    												},
    												toggleAction: {
    													parent: {
    														selector: "#optanon-popup-body-right"
    													},
    													target: {
    														selector: ".optanon-status label"
    													},
    													type: "click"
    												},
    												type: "B"
    											}
    										],
    										type: "consent"
    									}
    								],
    								type: "list"
    							},
    							type: "ifcss"
    						},
    						{
    							parent: {
    								selector: "#optanon-menu, .optanon-menu"
    							},
    							target: {
    								selector: ".menu-item-necessary",
    								textFilter: "Third party privacy-enhanced content"
    							},
    							trueAction: {
    								actions: [
    									{
    										parent: {
    											selector: "#optanon-menu, .optanon-menu"
    										},
    										target: {
    											selector: ".menu-item-necessary",
    											textFilter: "Third party privacy-enhanced content"
    										},
    										type: "click"
    									},
    									{
    										consents: [
    											{
    												matcher: {
    													parent: {
    														selector: "#optanon-popup-body-right"
    													},
    													target: {
    														selector: ".optanon-status input"
    													},
    													type: "checkbox"
    												},
    												toggleAction: {
    													parent: {
    														selector: "#optanon-popup-body-right"
    													},
    													target: {
    														selector: ".optanon-status label"
    													},
    													type: "click"
    												},
    												type: "X"
    											}
    										],
    										type: "consent"
    									}
    								],
    								type: "list"
    							},
    							type: "ifcss"
    						},
    						{
    							parent: {
    								selector: "#optanon-menu, .optanon-menu"
    							},
    							target: {
    								selector: ".menu-item-necessary",
    								textFilter: "Performance & Advertising Cookies"
    							},
    							trueAction: {
    								actions: [
    									{
    										parent: {
    											selector: "#optanon-menu, .optanon-menu"
    										},
    										target: {
    											selector: ".menu-item-necessary",
    											textFilter: "Performance & Advertising Cookies"
    										},
    										type: "click"
    									},
    									{
    										consents: [
    											{
    												matcher: {
    													parent: {
    														selector: "#optanon-popup-body-right"
    													},
    													target: {
    														selector: ".optanon-status input"
    													},
    													type: "checkbox"
    												},
    												toggleAction: {
    													parent: {
    														selector: "#optanon-popup-body-right"
    													},
    													target: {
    														selector: ".optanon-status label"
    													},
    													type: "click"
    												},
    												type: "F"
    											}
    										],
    										type: "consent"
    									}
    								],
    								type: "list"
    							},
    							type: "ifcss"
    						},
    						{
    							parent: {
    								selector: "#optanon-menu, .optanon-menu"
    							},
    							target: {
    								selector: ".menu-item-necessary",
    								textFilter: "Information storage and access"
    							},
    							trueAction: {
    								actions: [
    									{
    										parent: {
    											selector: "#optanon-menu, .optanon-menu"
    										},
    										target: {
    											selector: ".menu-item-necessary",
    											textFilter: "Information storage and access"
    										},
    										type: "click"
    									},
    									{
    										consents: [
    											{
    												matcher: {
    													parent: {
    														selector: "#optanon-popup-body-right"
    													},
    													target: {
    														selector: ".optanon-status input"
    													},
    													type: "checkbox"
    												},
    												toggleAction: {
    													parent: {
    														selector: "#optanon-popup-body-right"
    													},
    													target: {
    														selector: ".optanon-status label"
    													},
    													type: "click"
    												},
    												type: "D"
    											}
    										],
    										type: "consent"
    									}
    								],
    								type: "list"
    							},
    							type: "ifcss"
    						},
    						{
    							parent: {
    								selector: "#optanon-menu, .optanon-menu"
    							},
    							target: {
    								selector: ".menu-item-necessary",
    								textFilter: "Ad selection, delivery, reporting"
    							},
    							trueAction: {
    								actions: [
    									{
    										parent: {
    											selector: "#optanon-menu, .optanon-menu"
    										},
    										target: {
    											selector: ".menu-item-necessary",
    											textFilter: "Ad selection, delivery, reporting"
    										},
    										type: "click"
    									},
    									{
    										consents: [
    											{
    												matcher: {
    													parent: {
    														selector: "#optanon-popup-body-right"
    													},
    													target: {
    														selector: ".optanon-status input"
    													},
    													type: "checkbox"
    												},
    												toggleAction: {
    													parent: {
    														selector: "#optanon-popup-body-right"
    													},
    													target: {
    														selector: ".optanon-status label"
    													},
    													type: "click"
    												},
    												type: "F"
    											}
    										],
    										type: "consent"
    									}
    								],
    								type: "list"
    							},
    							type: "ifcss"
    						},
    						{
    							parent: {
    								selector: "#optanon-menu, .optanon-menu"
    							},
    							target: {
    								selector: ".menu-item-necessary",
    								textFilter: "Content selection, delivery, reporting"
    							},
    							trueAction: {
    								actions: [
    									{
    										parent: {
    											selector: "#optanon-menu, .optanon-menu"
    										},
    										target: {
    											selector: ".menu-item-necessary",
    											textFilter: "Content selection, delivery, reporting"
    										},
    										type: "click"
    									},
    									{
    										consents: [
    											{
    												matcher: {
    													parent: {
    														selector: "#optanon-popup-body-right"
    													},
    													target: {
    														selector: ".optanon-status input"
    													},
    													type: "checkbox"
    												},
    												toggleAction: {
    													parent: {
    														selector: "#optanon-popup-body-right"
    													},
    													target: {
    														selector: ".optanon-status label"
    													},
    													type: "click"
    												},
    												type: "E"
    											}
    										],
    										type: "consent"
    									}
    								],
    								type: "list"
    							},
    							type: "ifcss"
    						},
    						{
    							parent: {
    								selector: "#optanon-menu, .optanon-menu"
    							},
    							target: {
    								selector: ".menu-item-necessary",
    								textFilter: "Measurement"
    							},
    							trueAction: {
    								actions: [
    									{
    										parent: {
    											selector: "#optanon-menu, .optanon-menu"
    										},
    										target: {
    											selector: ".menu-item-necessary",
    											textFilter: "Measurement"
    										},
    										type: "click"
    									},
    									{
    										consents: [
    											{
    												matcher: {
    													parent: {
    														selector: "#optanon-popup-body-right"
    													},
    													target: {
    														selector: ".optanon-status input"
    													},
    													type: "checkbox"
    												},
    												toggleAction: {
    													parent: {
    														selector: "#optanon-popup-body-right"
    													},
    													target: {
    														selector: ".optanon-status label"
    													},
    													type: "click"
    												},
    												type: "B"
    											}
    										],
    										type: "consent"
    									}
    								],
    								type: "list"
    							},
    							type: "ifcss"
    						},
    						{
    							parent: {
    								selector: "#optanon-menu, .optanon-menu"
    							},
    							target: {
    								selector: ".menu-item-necessary",
    								textFilter: "Recommended Cookies"
    							},
    							trueAction: {
    								actions: [
    									{
    										parent: {
    											selector: "#optanon-menu, .optanon-menu"
    										},
    										target: {
    											selector: ".menu-item-necessary",
    											textFilter: "Recommended Cookies"
    										},
    										type: "click"
    									},
    									{
    										consents: [
    											{
    												matcher: {
    													parent: {
    														selector: "#optanon-popup-body-right"
    													},
    													target: {
    														selector: ".optanon-status input"
    													},
    													type: "checkbox"
    												},
    												toggleAction: {
    													parent: {
    														selector: "#optanon-popup-body-right"
    													},
    													target: {
    														selector: ".optanon-status label"
    													},
    													type: "click"
    												},
    												type: "X"
    											}
    										],
    										type: "consent"
    									}
    								],
    								type: "list"
    							},
    							type: "ifcss"
    						},
    						{
    							parent: {
    								selector: "#optanon-menu, .optanon-menu"
    							},
    							target: {
    								selector: ".menu-item-necessary",
    								textFilter: "Unclassified Cookies"
    							},
    							trueAction: {
    								actions: [
    									{
    										parent: {
    											selector: "#optanon-menu, .optanon-menu"
    										},
    										target: {
    											selector: ".menu-item-necessary",
    											textFilter: "Unclassified Cookies"
    										},
    										type: "click"
    									},
    									{
    										consents: [
    											{
    												matcher: {
    													parent: {
    														selector: "#optanon-popup-body-right"
    													},
    													target: {
    														selector: ".optanon-status input"
    													},
    													type: "checkbox"
    												},
    												toggleAction: {
    													parent: {
    														selector: "#optanon-popup-body-right"
    													},
    													target: {
    														selector: ".optanon-status label"
    													},
    													type: "click"
    												},
    												type: "X"
    											}
    										],
    										type: "consent"
    									}
    								],
    								type: "list"
    							},
    							type: "ifcss"
    						},
    						{
    							parent: {
    								selector: "#optanon-menu, .optanon-menu"
    							},
    							target: {
    								selector: ".menu-item-necessary",
    								textFilter: "Analytical Cookies"
    							},
    							trueAction: {
    								actions: [
    									{
    										parent: {
    											selector: "#optanon-menu, .optanon-menu"
    										},
    										target: {
    											selector: ".menu-item-necessary",
    											textFilter: "Analytical Cookies"
    										},
    										type: "click"
    									},
    									{
    										consents: [
    											{
    												matcher: {
    													parent: {
    														selector: "#optanon-popup-body-right"
    													},
    													target: {
    														selector: ".optanon-status input"
    													},
    													type: "checkbox"
    												},
    												toggleAction: {
    													parent: {
    														selector: "#optanon-popup-body-right"
    													},
    													target: {
    														selector: ".optanon-status label"
    													},
    													type: "click"
    												},
    												type: "B"
    											}
    										],
    										type: "consent"
    									}
    								],
    								type: "list"
    							},
    							type: "ifcss"
    						},
    						{
    							parent: {
    								selector: "#optanon-menu, .optanon-menu"
    							},
    							target: {
    								selector: ".menu-item-necessary",
    								textFilter: "Marketing Cookies"
    							},
    							trueAction: {
    								actions: [
    									{
    										parent: {
    											selector: "#optanon-menu, .optanon-menu"
    										},
    										target: {
    											selector: ".menu-item-necessary",
    											textFilter: "Marketing Cookies"
    										},
    										type: "click"
    									},
    									{
    										consents: [
    											{
    												matcher: {
    													parent: {
    														selector: "#optanon-popup-body-right"
    													},
    													target: {
    														selector: ".optanon-status input"
    													},
    													type: "checkbox"
    												},
    												toggleAction: {
    													parent: {
    														selector: "#optanon-popup-body-right"
    													},
    													target: {
    														selector: ".optanon-status label"
    													},
    													type: "click"
    												},
    												type: "F"
    											}
    										],
    										type: "consent"
    									}
    								],
    								type: "list"
    							},
    							type: "ifcss"
    						},
    						{
    							parent: {
    								selector: "#optanon-menu, .optanon-menu"
    							},
    							target: {
    								selector: ".menu-item-necessary",
    								textFilter: "Personalization"
    							},
    							trueAction: {
    								actions: [
    									{
    										parent: {
    											selector: "#optanon-menu, .optanon-menu"
    										},
    										target: {
    											selector: ".menu-item-necessary",
    											textFilter: "Personalization"
    										},
    										type: "click"
    									},
    									{
    										consents: [
    											{
    												matcher: {
    													parent: {
    														selector: "#optanon-popup-body-right"
    													},
    													target: {
    														selector: ".optanon-status input"
    													},
    													type: "checkbox"
    												},
    												toggleAction: {
    													parent: {
    														selector: "#optanon-popup-body-right"
    													},
    													target: {
    														selector: ".optanon-status label"
    													},
    													type: "click"
    												},
    												type: "E"
    											}
    										],
    										type: "consent"
    									}
    								],
    								type: "list"
    							},
    							type: "ifcss"
    						},
    						{
    							parent: {
    								selector: "#optanon-menu, .optanon-menu"
    							},
    							target: {
    								selector: ".menu-item-necessary",
    								textFilter: "Ad Selection, Delivery & Reporting"
    							},
    							trueAction: {
    								actions: [
    									{
    										parent: {
    											selector: "#optanon-menu, .optanon-menu"
    										},
    										target: {
    											selector: ".menu-item-necessary",
    											textFilter: "Ad Selection, Delivery & Reporting"
    										},
    										type: "click"
    									},
    									{
    										consents: [
    											{
    												matcher: {
    													parent: {
    														selector: "#optanon-popup-body-right"
    													},
    													target: {
    														selector: ".optanon-status input"
    													},
    													type: "checkbox"
    												},
    												toggleAction: {
    													parent: {
    														selector: "#optanon-popup-body-right"
    													},
    													target: {
    														selector: ".optanon-status label"
    													},
    													type: "click"
    												},
    												type: "F"
    											}
    										],
    										type: "consent"
    									}
    								],
    								type: "list"
    							},
    							type: "ifcss"
    						},
    						{
    							parent: {
    								selector: "#optanon-menu, .optanon-menu"
    							},
    							target: {
    								selector: ".menu-item-necessary",
    								textFilter: "Content Selection, Delivery & Reporting"
    							},
    							trueAction: {
    								actions: [
    									{
    										parent: {
    											selector: "#optanon-menu, .optanon-menu"
    										},
    										target: {
    											selector: ".menu-item-necessary",
    											textFilter: "Content Selection, Delivery & Reporting"
    										},
    										type: "click"
    									},
    									{
    										consents: [
    											{
    												matcher: {
    													parent: {
    														selector: "#optanon-popup-body-right"
    													},
    													target: {
    														selector: ".optanon-status input"
    													},
    													type: "checkbox"
    												},
    												toggleAction: {
    													parent: {
    														selector: "#optanon-popup-body-right"
    													},
    													target: {
    														selector: ".optanon-status label"
    													},
    													type: "click"
    												},
    												type: "E"
    											}
    										],
    										type: "consent"
    									}
    								],
    								type: "list"
    							},
    							type: "ifcss"
    						}
    					],
    					type: "list"
    				},
    				name: "DO_CONSENT"
    			},
    			{
    				action: {
    					parent: {
    						selector: ".optanon-save-settings-button"
    					},
    					target: {
    						selector: ".optanon-white-button-middle"
    					},
    					type: "click"
    				},
    				name: "SAVE_CONSENT"
    			},
    			{
    				action: {
    					actions: [
    						{
    							target: {
    								selector: "#optanon-popup-wrapper"
    							},
    							type: "hide"
    						},
    						{
    							target: {
    								selector: "#optanon-popup-bg"
    							},
    							type: "hide"
    						},
    						{
    							target: {
    								selector: ".optanon-alert-box-wrapper"
    							},
    							type: "hide"
    						}
    					],
    					type: "list"
    				},
    				name: "HIDE_CMP"
    			}
    		]
    	},
    	quantcast2: {
    		detectors: [
    			{
    				presentMatcher: {
    					target: {
    						selector: "[data-tracking-opt-in-overlay]"
    					},
    					type: "css"
    				},
    				showingMatcher: {
    					target: {
    						selector: "[data-tracking-opt-in-overlay] [data-tracking-opt-in-learn-more]"
    					},
    					type: "css"
    				}
    			}
    		],
    		methods: [
    			{
    				action: {
    					target: {
    						selector: "[data-tracking-opt-in-overlay] [data-tracking-opt-in-learn-more]"
    					},
    					type: "click"
    				},
    				name: "OPEN_OPTIONS"
    			},
    			{
    				action: {
    					actions: [
    						{
    							type: "wait",
    							waitTime: 500
    						},
    						{
    							action: {
    								actions: [
    									{
    										target: {
    											selector: "div",
    											textFilter: [
    												"Information storage and access"
    											]
    										},
    										trueAction: {
    											consents: [
    												{
    													matcher: {
    														target: {
    															selector: "input"
    														},
    														type: "checkbox"
    													},
    													toggleAction: {
    														target: {
    															selector: "label"
    														},
    														type: "click"
    													},
    													type: "D"
    												}
    											],
    											type: "consent"
    										},
    										type: "ifcss"
    									},
    									{
    										target: {
    											selector: "div",
    											textFilter: [
    												"Personalization"
    											]
    										},
    										trueAction: {
    											consents: [
    												{
    													matcher: {
    														target: {
    															selector: "input"
    														},
    														type: "checkbox"
    													},
    													toggleAction: {
    														target: {
    															selector: "label"
    														},
    														type: "click"
    													},
    													type: "F"
    												}
    											],
    											type: "consent"
    										},
    										type: "ifcss"
    									},
    									{
    										target: {
    											selector: "div",
    											textFilter: [
    												"Ad selection, delivery, reporting"
    											]
    										},
    										trueAction: {
    											consents: [
    												{
    													matcher: {
    														target: {
    															selector: "input"
    														},
    														type: "checkbox"
    													},
    													toggleAction: {
    														target: {
    															selector: "label"
    														},
    														type: "click"
    													},
    													type: "F"
    												}
    											],
    											type: "consent"
    										},
    										type: "ifcss"
    									},
    									{
    										target: {
    											selector: "div",
    											textFilter: [
    												"Content selection, delivery, reporting"
    											]
    										},
    										trueAction: {
    											consents: [
    												{
    													matcher: {
    														target: {
    															selector: "input"
    														},
    														type: "checkbox"
    													},
    													toggleAction: {
    														target: {
    															selector: "label"
    														},
    														type: "click"
    													},
    													type: "E"
    												}
    											],
    											type: "consent"
    										},
    										type: "ifcss"
    									},
    									{
    										target: {
    											selector: "div",
    											textFilter: [
    												"Measurement"
    											]
    										},
    										trueAction: {
    											consents: [
    												{
    													matcher: {
    														target: {
    															selector: "input"
    														},
    														type: "checkbox"
    													},
    													toggleAction: {
    														target: {
    															selector: "label"
    														},
    														type: "click"
    													},
    													type: "B"
    												}
    											],
    											type: "consent"
    										},
    										type: "ifcss"
    									},
    									{
    										target: {
    											selector: "div",
    											textFilter: [
    												"Other Partners"
    											]
    										},
    										trueAction: {
    											consents: [
    												{
    													matcher: {
    														target: {
    															selector: "input"
    														},
    														type: "checkbox"
    													},
    													toggleAction: {
    														target: {
    															selector: "label"
    														},
    														type: "click"
    													},
    													type: "X"
    												}
    											],
    											type: "consent"
    										},
    										type: "ifcss"
    									}
    								],
    								type: "list"
    							},
    							parent: {
    								childFilter: {
    									target: {
    										selector: "input"
    									}
    								},
    								selector: "[data-tracking-opt-in-overlay] > div > div"
    							},
    							target: {
    								childFilter: {
    									target: {
    										selector: "input"
    									}
    								},
    								selector: ":scope > div"
    							},
    							type: "foreach"
    						}
    					],
    					type: "list"
    				},
    				name: "DO_CONSENT"
    			},
    			{
    				action: {
    					target: {
    						selector: "[data-tracking-opt-in-overlay] [data-tracking-opt-in-save]"
    					},
    					type: "click"
    				},
    				name: "SAVE_CONSENT"
    			}
    		]
    	},
    	springer: {
    		detectors: [
    			{
    				presentMatcher: {
    					parent: null,
    					target: {
    						selector: ".cmp-app_gdpr"
    					},
    					type: "css"
    				},
    				showingMatcher: {
    					parent: null,
    					target: {
    						displayFilter: true,
    						selector: ".cmp-popup_popup"
    					},
    					type: "css"
    				}
    			}
    		],
    		methods: [
    			{
    				action: {
    					actions: [
    						{
    							target: {
    								selector: ".cmp-intro_rejectAll"
    							},
    							type: "click"
    						},
    						{
    							type: "wait",
    							waitTime: 250
    						},
    						{
    							target: {
    								selector: ".cmp-purposes_purposeItem:not(.cmp-purposes_selectedPurpose)"
    							},
    							type: "click"
    						}
    					],
    					type: "list"
    				},
    				name: "OPEN_OPTIONS"
    			},
    			{
    				action: {
    					consents: [
    						{
    							matcher: {
    								parent: {
    									selector: ".cmp-purposes_detailHeader",
    									textFilter: "Przechowywanie informacji na urządzeniu lub dostęp do nich",
    									childFilter: {
    										target: {
    											selector: ".cmp-switch_switch"
    										}
    									}
    								},
    								target: {
    									selector: ".cmp-switch_switch .cmp-switch_isSelected"
    								},
    								type: "css"
    							},
    							toggleAction: {
    								parent: {
    									selector: ".cmp-purposes_detailHeader",
    									textFilter: "Przechowywanie informacji na urządzeniu lub dostęp do nich",
    									childFilter: {
    										target: {
    											selector: ".cmp-switch_switch"
    										}
    									}
    								},
    								target: {
    									selector: ".cmp-switch_switch:not(.cmp-switch_isSelected)"
    								},
    								type: "click"
    							},
    							type: "D"
    						},
    						{
    							matcher: {
    								parent: {
    									selector: ".cmp-purposes_detailHeader",
    									textFilter: "Wybór podstawowych reklam",
    									childFilter: {
    										target: {
    											selector: ".cmp-switch_switch"
    										}
    									}
    								},
    								target: {
    									selector: ".cmp-switch_switch .cmp-switch_isSelected"
    								},
    								type: "css"
    							},
    							toggleAction: {
    								parent: {
    									selector: ".cmp-purposes_detailHeader",
    									textFilter: "Wybór podstawowych reklam",
    									childFilter: {
    										target: {
    											selector: ".cmp-switch_switch"
    										}
    									}
    								},
    								target: {
    									selector: ".cmp-switch_switch:not(.cmp-switch_isSelected)"
    								},
    								type: "click"
    							},
    							type: "F"
    						},
    						{
    							matcher: {
    								parent: {
    									selector: ".cmp-purposes_detailHeader",
    									textFilter: "Tworzenie profilu spersonalizowanych reklam",
    									childFilter: {
    										target: {
    											selector: ".cmp-switch_switch"
    										}
    									}
    								},
    								target: {
    									selector: ".cmp-switch_switch .cmp-switch_isSelected"
    								},
    								type: "css"
    							},
    							toggleAction: {
    								parent: {
    									selector: ".cmp-purposes_detailHeader",
    									textFilter: "Tworzenie profilu spersonalizowanych reklam",
    									childFilter: {
    										target: {
    											selector: ".cmp-switch_switch"
    										}
    									}
    								},
    								target: {
    									selector: ".cmp-switch_switch:not(.cmp-switch_isSelected)"
    								},
    								type: "click"
    							},
    							type: "F"
    						},
    						{
    							matcher: {
    								parent: {
    									selector: ".cmp-purposes_detailHeader",
    									textFilter: "Wybór spersonalizowanych reklam",
    									childFilter: {
    										target: {
    											selector: ".cmp-switch_switch"
    										}
    									}
    								},
    								target: {
    									selector: ".cmp-switch_switch .cmp-switch_isSelected"
    								},
    								type: "css"
    							},
    							toggleAction: {
    								parent: {
    									selector: ".cmp-purposes_detailHeader",
    									textFilter: "Wybór spersonalizowanych reklam",
    									childFilter: {
    										target: {
    											selector: ".cmp-switch_switch"
    										}
    									}
    								},
    								target: {
    									selector: ".cmp-switch_switch:not(.cmp-switch_isSelected)"
    								},
    								type: "click"
    							},
    							type: "E"
    						},
    						{
    							matcher: {
    								parent: {
    									selector: ".cmp-purposes_detailHeader",
    									textFilter: "Tworzenie profilu spersonalizowanych treści",
    									childFilter: {
    										target: {
    											selector: ".cmp-switch_switch"
    										}
    									}
    								},
    								target: {
    									selector: ".cmp-switch_switch .cmp-switch_isSelected"
    								},
    								type: "css"
    							},
    							toggleAction: {
    								parent: {
    									selector: ".cmp-purposes_detailHeader",
    									textFilter: "Tworzenie profilu spersonalizowanych treści",
    									childFilter: {
    										target: {
    											selector: ".cmp-switch_switch"
    										}
    									}
    								},
    								target: {
    									selector: ".cmp-switch_switch:not(.cmp-switch_isSelected)"
    								},
    								type: "click"
    							},
    							type: "E"
    						},
    						{
    							matcher: {
    								parent: {
    									selector: ".cmp-purposes_detailHeader",
    									textFilter: "Wybór spersonalizowanych treści",
    									childFilter: {
    										target: {
    											selector: ".cmp-switch_switch"
    										}
    									}
    								},
    								target: {
    									selector: ".cmp-switch_switch .cmp-switch_isSelected"
    								},
    								type: "css"
    							},
    							toggleAction: {
    								parent: {
    									selector: ".cmp-purposes_detailHeader",
    									textFilter: "Wybór spersonalizowanych treści",
    									childFilter: {
    										target: {
    											selector: ".cmp-switch_switch"
    										}
    									}
    								},
    								target: {
    									selector: ".cmp-switch_switch:not(.cmp-switch_isSelected)"
    								},
    								type: "click"
    							},
    							type: "B"
    						},
    						{
    							matcher: {
    								parent: {
    									selector: ".cmp-purposes_detailHeader",
    									textFilter: "Pomiar wydajności reklam",
    									childFilter: {
    										target: {
    											selector: ".cmp-switch_switch"
    										}
    									}
    								},
    								target: {
    									selector: ".cmp-switch_switch .cmp-switch_isSelected"
    								},
    								type: "css"
    							},
    							toggleAction: {
    								parent: {
    									selector: ".cmp-purposes_detailHeader",
    									textFilter: "Pomiar wydajności reklam",
    									childFilter: {
    										target: {
    											selector: ".cmp-switch_switch"
    										}
    									}
    								},
    								target: {
    									selector: ".cmp-switch_switch:not(.cmp-switch_isSelected)"
    								},
    								type: "click"
    							},
    							type: "B"
    						},
    						{
    							matcher: {
    								parent: {
    									selector: ".cmp-purposes_detailHeader",
    									textFilter: "Pomiar wydajności treści",
    									childFilter: {
    										target: {
    											selector: ".cmp-switch_switch"
    										}
    									}
    								},
    								target: {
    									selector: ".cmp-switch_switch .cmp-switch_isSelected"
    								},
    								type: "css"
    							},
    							toggleAction: {
    								parent: {
    									selector: ".cmp-purposes_detailHeader",
    									textFilter: "Pomiar wydajności treści",
    									childFilter: {
    										target: {
    											selector: ".cmp-switch_switch"
    										}
    									}
    								},
    								target: {
    									selector: ".cmp-switch_switch:not(.cmp-switch_isSelected)"
    								},
    								type: "click"
    							},
    							type: "B"
    						},
    						{
    							matcher: {
    								parent: {
    									selector: ".cmp-purposes_detailHeader",
    									textFilter: "Stosowanie badań rynkowych w celu generowania opinii odbiorców",
    									childFilter: {
    										target: {
    											selector: ".cmp-switch_switch"
    										}
    									}
    								},
    								target: {
    									selector: ".cmp-switch_switch .cmp-switch_isSelected"
    								},
    								type: "css"
    							},
    							toggleAction: {
    								parent: {
    									selector: ".cmp-purposes_detailHeader",
    									textFilter: "Stosowanie badań rynkowych w celu generowania opinii odbiorców",
    									childFilter: {
    										target: {
    											selector: ".cmp-switch_switch"
    										}
    									}
    								},
    								target: {
    									selector: ".cmp-switch_switch:not(.cmp-switch_isSelected)"
    								},
    								type: "click"
    							},
    							type: "X"
    						},
    						{
    							matcher: {
    								parent: {
    									selector: ".cmp-purposes_detailHeader",
    									textFilter: "Opracowywanie i ulepszanie produktów",
    									childFilter: {
    										target: {
    											selector: ".cmp-switch_switch"
    										}
    									}
    								},
    								target: {
    									selector: ".cmp-switch_switch .cmp-switch_isSelected"
    								},
    								type: "css"
    							},
    							toggleAction: {
    								parent: {
    									selector: ".cmp-purposes_detailHeader",
    									textFilter: "Opracowywanie i ulepszanie produktów",
    									childFilter: {
    										target: {
    											selector: ".cmp-switch_switch"
    										}
    									}
    								},
    								target: {
    									selector: ".cmp-switch_switch:not(.cmp-switch_isSelected)"
    								},
    								type: "click"
    							},
    							type: "X"
    						}
    					],
    					type: "consent"
    				},
    				name: "DO_CONSENT"
    			},
    			{
    				action: {
    					target: {
    						selector: ".cmp-details_save"
    					},
    					type: "click"
    				},
    				name: "SAVE_CONSENT"
    			}
    		]
    	},
    	wordpressgdpr: {
    		detectors: [
    			{
    				presentMatcher: {
    					parent: null,
    					target: {
    						selector: ".wpgdprc-consent-bar"
    					},
    					type: "css"
    				},
    				showingMatcher: {
    					parent: null,
    					target: {
    						displayFilter: true,
    						selector: ".wpgdprc-consent-bar"
    					},
    					type: "css"
    				}
    			}
    		],
    		methods: [
    			{
    				action: {
    					parent: null,
    					target: {
    						selector: ".wpgdprc-consent-bar .wpgdprc-consent-bar__settings",
    						textFilter: null
    					},
    					type: "click"
    				},
    				name: "OPEN_OPTIONS"
    			},
    			{
    				action: {
    					actions: [
    						{
    							target: {
    								selector: ".wpgdprc-consent-modal .wpgdprc-button",
    								textFilter: "Eyeota"
    							},
    							type: "click"
    						},
    						{
    							consents: [
    								{
    									description: "Eyeota Cookies",
    									matcher: {
    										parent: {
    											selector: ".wpgdprc-consent-modal__description",
    											textFilter: "Eyeota"
    										},
    										target: {
    											selector: "input"
    										},
    										type: "checkbox"
    									},
    									toggleAction: {
    										parent: {
    											selector: ".wpgdprc-consent-modal__description",
    											textFilter: "Eyeota"
    										},
    										target: {
    											selector: "label"
    										},
    										type: "click"
    									},
    									type: "X"
    								}
    							],
    							type: "consent"
    						},
    						{
    							target: {
    								selector: ".wpgdprc-consent-modal .wpgdprc-button",
    								textFilter: "Advertising"
    							},
    							type: "click"
    						},
    						{
    							consents: [
    								{
    									description: "Advertising Cookies",
    									matcher: {
    										parent: {
    											selector: ".wpgdprc-consent-modal__description",
    											textFilter: "Advertising"
    										},
    										target: {
    											selector: "input"
    										},
    										type: "checkbox"
    									},
    									toggleAction: {
    										parent: {
    											selector: ".wpgdprc-consent-modal__description",
    											textFilter: "Advertising"
    										},
    										target: {
    											selector: "label"
    										},
    										type: "click"
    									},
    									type: "F"
    								}
    							],
    							type: "consent"
    						}
    					],
    					type: "list"
    				},
    				name: "DO_CONSENT"
    			},
    			{
    				action: {
    					parent: null,
    					target: {
    						selector: ".wpgdprc-button",
    						textFilter: "Save my settings"
    					},
    					type: "click"
    				},
    				name: "SAVE_CONSENT"
    			}
    		]
    	}
    };
    var rules = {
    	autoconsent: autoconsent,
    	consentomatic: consentomatic
    };

    var rules$1 = /*#__PURE__*/Object.freeze({
        __proto__: null,
        autoconsent: autoconsent,
        consentomatic: consentomatic,
        'default': rules
    });

    /* global browser */

    const consent = new AutoConsent(browser, browser.tabs.sendMessage);

    async function loadRules () {
        console.log(rules$1);
        Object.keys(consentomatic).forEach((name) => {
            consent.addConsentomaticCMP(name, consentomatic[name]);
        });
        autoconsent.forEach((rule) => {
            consent.addCMP(rule);
        });
        console.log('rules loaded', consent.rules.length);
    }

    loadRules();

    browser.webNavigation.onCommitted.addListener((details) => {
        if (details.frameId === 0) {
            console.log('Received onCommitted, removing tab', details.tabId);
            consent.removeTab(details.tabId);
        }
    }, {
        url: [{ schemes: ['http', 'https'] }]
    });

    browser.webNavigation.onCompleted.addListener(
        (args) => {
            console.log('Received onCompleted, running onFrame()', args);
            return consent.onFrame(args);
        }, {
            url: [{ schemes: ['http', 'https'] }]
        }
    );

    window.autoconsent = consent;

    window.callAction = (messageId, tabId, action) => {
        const respond = (obj) => {
            window.webkit.messageHandlers.actionResponse.postMessage(JSON.stringify({
                messageId,
                ...obj
            })).catch(() => console.warn('Error sending response', messageId, obj));
        };
        const errorResponse = (err) => {
            console.warn('action error', err);
            respond({ result: false, error: err.toString() });
        };

        if (action === 'detectCMP') {
            console.log(`detecting cmp for tab ${tabId}`);
            consent.checkTab(tabId).then(async (cmp) => {
                try {
                    await cmp.checked;
                    console.log('cmp detection finished', cmp.getCMPName());
                    respond({
                        ruleName: cmp.getCMPName(),
                        result: cmp.getCMPName() !== null
                    });
                } catch (e) {
                    errorResponse(e);
                }
            }, errorResponse);
        } else {
            const cmp = consent.tabCmps.get(tabId);
            if (!cmp) {
                respond({
                    result: false
                });
                return
            }
            const successResponse = (result) => respond({ ruleName: cmp.getCMPName(), result });
            switch (action) {
            case 'detectPopup':
                // give up after (20 * 200) ms
                cmp.isPopupOpen(20, 200).then(successResponse, errorResponse);
                break
            case 'doOptOut':
                cmp.doOptOut().then(successResponse, errorResponse);
                break
            case 'selfTest':
                if (!cmp.hasTest()) {
                    errorResponse('no test for this CMP');
                } else {
                    cmp.testOptOutWorked().then(successResponse, errorResponse);
                }
                break
            }
        }
        return messageId
    };

})();
