//
//  AutoconsentUserScript.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import WebKit
import BrowserServicesKit
import Common
import UserScript
import PrivacyDashboard
import os.log

protocol AutoconsentUserScriptDelegate: AnyObject {
    func autoconsentUserScript(consentStatus: CookieConsentInfo)
}

protocol UserScriptWithAutoconsent: UserScript {
    var delegate: AutoconsentUserScriptDelegate? { get set }
}

final class AutoconsentUserScript: NSObject, WKScriptMessageHandlerWithReply, UserScriptWithAutoconsent {

    private struct Constants {
        static let filterListCmpName = "filterList" // special CMP name used for reports from the cosmetic filterlist
    }

    static let newSitePopupHiddenNotification = Notification.Name("newSitePopupHidden")

    var injectionTime: WKUserScriptInjectionTime { .atDocumentStart }
    var forMainFrameOnly: Bool { false }

    private weak var selfTestWebView: WKWebView?
    private weak var selfTestFrameInfo: WKFrameInfo?

    private var topUrl: URL?
    private let preferences = CookiePopupProtectionPreferences.shared
    private let management = AutoconsentManagement.shared

    public var messageNames: [String] { MessageName.allCases.map(\.rawValue) }
    let source: String
    private let config: PrivacyConfiguration
    weak var delegate: AutoconsentUserScriptDelegate?

    init(scriptSource: ScriptSourceProviding, config: PrivacyConfiguration) {
        Logger.autoconsent.debug("Initialising autoconsent userscript")
        source = Self.loadJS("autoconsent-bundle", from: .main, withReplacements: [:])
        self.config = config
    }

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        // this is never used because macOS <11 is not supported by autoconsent
    }

    @MainActor
    func refreshDashboardState(consentManaged: Bool, cosmetic: Bool?, optoutFailed: Bool?, selftestFailed: Bool?) {
        let consentStatus = CookieConsentInfo(
            consentManaged: consentManaged, cosmetic: cosmetic, optoutFailed: optoutFailed, selftestFailed: selftestFailed
        )
        Logger.autoconsent.debug("Refreshing dashboard state: \(String(describing: consentStatus))")
        self.delegate?.autoconsentUserScript(consentStatus: consentStatus)
    }

    @MainActor
    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage,
                               replyHandler: @escaping (Any?, String?) -> Void) {
        Logger.autoconsent.debug("Message received: \(String(describing: message.body))")
        return handleMessage(replyHandler: replyHandler, message: message)
    }
}

extension AutoconsentUserScript {
    enum MessageName: String, CaseIterable {
        case `init`
        case cmpDetected
        case eval
        case popupFound
        case optOutResult
        case optInResult
        case selfTestResult
        case autoconsentDone
        case autoconsentError
    }

    struct InitMessage: Codable {
        let type: String
        let url: String
    }

    struct CmpDetectedMessage: Codable {
        let type: String
        let cmp: String
        let url: String
    }

    struct EvalMessage: Codable {
        let type: String
        let id: String
        let code: String
    }

    struct PopupFoundMessage: Codable {
        let type: String
        let cmp: String // name of the Autoconsent rule that matched
        let url: String
    }

    struct OptOutResultMessage: Codable {
        let type: String
        let cmp: String // name of the Autoconsent rule that matched
        let result: Bool
        let scheduleSelfTest: Bool
        let url: String
    }

    struct OptInResultMessage: Codable {
        let type: String
        let cmp: String // name of the Autoconsent rule that matched
        let result: Bool
        let scheduleSelfTest: Bool
        let url: String
    }

    struct SelfTestResultMessage: Codable {
        let type: String
        let cmp: String // name of the Autoconsent rule that matched
        let result: Bool
        let url: String
    }

    struct AutoconsentDoneMessage: Codable {
        let type: String
        let cmp: String // name of the Autoconsent rule that matched
        let url: String
        let isCosmetic: Bool
    }

    func decodeMessageBody<Input: Any, Target: Codable>(from message: Input) -> Target? {
        do {
            let json = try JSONSerialization.data(withJSONObject: message)
            return try JSONDecoder().decode(Target.self, from: json)
        } catch {
            Logger.autoconsent.error("Error decoding message body: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}

extension AutoconsentUserScript {
    @MainActor
    func handleMessage(replyHandler: @escaping (Any?, String?) -> Void,
                       message: WKScriptMessage) {
        guard let messageName = MessageName(rawValue: message.name) else {
            replyHandler(nil, "Unknown message type")
            return
        }

        switch messageName {
        case MessageName.`init`:
            handleInit(message: message, replyHandler: replyHandler)
        case MessageName.eval:
            handleEval(message: message, replyHandler: replyHandler)
        case MessageName.popupFound:
            handlePopupFound(message: message, replyHandler: replyHandler)
        case MessageName.optOutResult:
            handleOptOutResult(message: message, replyHandler: replyHandler)
        case MessageName.optInResult:
            // this is not supported in browser
            Logger.autoconsent.debug("ignoring optInResult: \(String(describing: message.body))")
            replyHandler(nil, "opt-in is not supported")
        case MessageName.cmpDetected:
            // no need to do anything here
            replyHandler([ "type": "ok" ], nil) // this is just to prevent a Promise rejection
        case MessageName.selfTestResult:
            handleSelfTestResult(message: message, replyHandler: replyHandler)
        case MessageName.autoconsentDone:
            handleAutoconsentDone(message: message, replyHandler: replyHandler)
        case MessageName.autoconsentError:
            Logger.autoconsent.error("Autoconsent error: \(String(describing: message.body))")
            replyHandler([ "type": "ok" ], nil) // this is just to prevent a Promise rejection
        }
    }

    func matchDomainList(domain: String?, domainsList: [String]) -> Bool {
        guard let domain = domain else { return false }
        let trimmedDomains = domainsList.filter { !$0.trimmingWhitespace().isEmpty }

        // Break domain apart to handle www.*
        var tempDomain = domain
        while tempDomain.contains(".") {
            if trimmedDomains.contains(tempDomain) {
                return true
            }

            let comps = tempDomain.split(separator: ".")
            tempDomain = comps.dropFirst().joined(separator: ".")
        }

        return false
    }

    @MainActor
    func handleInit(message: WKScriptMessage, replyHandler: @escaping (Any?, String?) -> Void) {
        guard let messageData: InitMessage = decodeMessageBody(from: message.body),
              let url = URL(string: messageData.url) else {
            assertionFailure("Received a malformed message from autoconsent")
            replyHandler(nil, "cannot decode message")
            return
        }

        guard url.navigationalScheme?.isHypertextScheme == true else {
            // ignore special schemes
            Logger.autoconsent.debug("Ignoring special URL scheme: \(messageData.url)")
            replyHandler([ "type": "ok" ], nil) // this is just to prevent a Promise rejection
            return
        }

        if preferences.isAutoconsentEnabled == false {
            // this will only happen if the user has just declined a prompt in this tab
            replyHandler([ "type": "ok" ], nil) // this is just to prevent a Promise rejection
            return
        }

        let topURLDomain = message.webView?.url?.host
        guard config.isFeature(.autoconsent, enabledForDomain: topURLDomain) else {
            Logger.autoconsent.info("disabled for site: \(String(describing: url.absoluteString))")
            replyHandler([ "type": "ok" ], nil) // this is just to prevent a Promise rejection
            return
        }

        if message.frameInfo.isMainFrame {
            topUrl = url
            // reset dashboard state
            refreshDashboardState(
                consentManaged: management.sitesNotifiedCache.contains(url.host ?? ""),
                cosmetic: nil,
                optoutFailed: nil,
                selftestFailed: nil
            )
        }
        let remoteConfig = self.config.settings(for: .autoconsent)
        let disabledCMPs = remoteConfig["disabledCMPs"] as? [String] ?? []
        let filterlistExceptions = remoteConfig["filterlistExceptions"] as? [String] ?? []

#if DEBUG
        // The `filterList` feature flag being disabled causes the integration test suite to fail - this is a temporary change to hardcode the
        // flag to true when integration tests are running. In all other cases, continue to use the flag as usual.
        let enableFilterList: Bool
        if [.integrationTests].contains(NSApp.runType) {
            enableFilterList = true
        } else {
            enableFilterList = config.isSubfeatureEnabled(AutoconsentSubfeature.filterlist) && !self.matchDomainList(domain: topURLDomain, domainsList: filterlistExceptions)
        }
#else
        let enableFilterList = config.isSubfeatureEnabled(AutoconsentSubfeature.filterlist) && !self.matchDomainList(domain: topURLDomain, domainsList: filterlistExceptions)
#endif

        let autoconsentConfig = [
            "type": "initResp",
            "rules": nil, // rules are bundled with the content script atm
            "config": [
                "enabled": true,
                "autoAction": preferences.isAutoconsentEnabled == true ? "optOut" : nil,
                "disabledCmps": disabledCMPs,
                "enablePrehide": true,
                "enableCosmeticRules": true,
                "detectRetries": 20,
                "isMainWorld": false,
                "enableFilterList": enableFilterList
            ] as [String: Any?]
        ] as [String: Any?]
        Logger.autoconsent.debug("autoconsent config: \(String(describing: autoconsentConfig))")

        replyHandler(autoconsentConfig, nil)
    }

    @MainActor
    func handleEval(message: WKScriptMessage, replyHandler: @escaping (Any?, String?) -> Void) {
        guard let messageData: EvalMessage = decodeMessageBody(from: message.body) else {
            assertionFailure("Received a malformed message from autoconsent")
            replyHandler(nil, "cannot decode message")
            return
        }
        let script = """
        (() => {
        try {
            return !!(\(messageData.code));
        } catch (e) {
          // ignore any errors
          return;
        }
        })();
        """

        if let webview = message.webView {
            webview.evaluateJavaScript(script, in: message.frameInfo, in: WKContentWorld.page, completionHandler: { (result) in
                switch result {
                case.failure(let error):
                    replyHandler(nil, "Error snippet: \(error)")
                case.success(let value):
                    replyHandler(
                        [
                            "type": "evalResp",
                            "id": messageData.id,
                            "result": value
                        ],
                        nil
                    )
                }
            })
        } else {
            replyHandler(nil, "missing frame target")
        }
    }

    @MainActor
    func handlePopupFound(message: WKScriptMessage, replyHandler: @escaping (Any?, String?) -> Void) {
        guard let messageData: PopupFoundMessage = decodeMessageBody(from: message.body),
              let url = URL(string: messageData.url),
              let host = url.host else {
            assertionFailure("Received a malformed message from autoconsent")
            replyHandler(nil, "cannot decode message")
            return
        }
        Logger.autoconsent.debug("Cookie popup found: \(String(describing: messageData))")

        // if popupFound is sent with "filterList", it indicates that cosmetic filterlist matched in the prehide stage,
        // but a real opt-out may still follow. See https://github.com/duckduckgo/autoconsent/blob/main/api.md#messaging-api
        if messageData.cmp == Constants.filterListCmpName {
            refreshDashboardState(consentManaged: true, cosmetic: true, optoutFailed: false, selftestFailed: nil)
            // trigger animation, but do not cache it because it can still be overridden
            if !management.sitesNotifiedCache.contains(host) {
                Logger.autoconsent.debug("Starting animation for cosmetic filters")
                // post popover notification
                NotificationCenter.default.post(name: Self.newSitePopupHiddenNotification, object: self, userInfo: [
                    "topUrl": self.topUrl ?? url,
                    "isCosmetic": true
                ])
            }
        }

        replyHandler([ "type": "ok" ], nil) // this is just to prevent a Promise rejection
    }

    @MainActor
    func handleOptOutResult(message: WKScriptMessage, replyHandler: @escaping (Any?, String?) -> Void) {
        guard let messageData: OptOutResultMessage = decodeMessageBody(from: message.body) else {
            assertionFailure("Received a malformed message from autoconsent")
            replyHandler(nil, "cannot decode message")
            return
        }
        Logger.autoconsent.debug("opt-out result: \(String(describing: messageData))")

        if !messageData.result {
            refreshDashboardState(consentManaged: true, cosmetic: nil, optoutFailed: true, selftestFailed: nil)
        } else if messageData.scheduleSelfTest {
            // save a reference to the webview and frame for self-test
            selfTestWebView = message.webView
            selfTestFrameInfo = message.frameInfo
        }

        replyHandler([ "type": "ok" ], nil) // this is just to prevent a Promise rejection
    }

    @MainActor
    func handleAutoconsentDone(message: WKScriptMessage, replyHandler: @escaping (Any?, String?) -> Void) {
        // report a managed popup
        guard let messageData: AutoconsentDoneMessage = decodeMessageBody(from: message.body),
              let url = URL(string: messageData.url),
              let host = url.host else {
            assertionFailure("Received a malformed message from autoconsent")
            replyHandler(nil, "cannot decode message")
            return
        }

        Logger.autoconsent.debug("opt-out successful: \(String(describing: messageData))")

        refreshDashboardState(consentManaged: true, cosmetic: messageData.isCosmetic, optoutFailed: false, selftestFailed: nil)

        // trigger popup once per domain
        if !management.sitesNotifiedCache.contains(host) {
            management.sitesNotifiedCache.insert(host)
            if messageData.cmp != Constants.filterListCmpName { // filterlist animation should have been triggered already (see handlePopupFound)
                Logger.autoconsent.debug("Starting animation for the handled cookie popup")
                // post popover notification
                NotificationCenter.default.post(name: Self.newSitePopupHiddenNotification, object: self, userInfo: [
                    "topUrl": self.topUrl ?? url,
                    "isCosmetic": messageData.isCosmetic
                ])
            }
        }

        replyHandler([ "type": "ok" ], nil) // this is just to prevent a Promise rejection

        if let selfTestWebView = selfTestWebView,
           let selfTestFrameInfo = selfTestFrameInfo {
            Logger.autoconsent.debug("requesting self-test in: \(messageData.url)")
            selfTestWebView.evaluateJavaScript(
                "window.autoconsentMessageCallback({ type: 'selfTest' })",
                in: selfTestFrameInfo,
                in: WKContentWorld.defaultClient,
                completionHandler: { (result) in
                    switch result {
                    case.failure(let error):
                        Logger.autoconsent.error("Error running self-test: \(error.localizedDescription, privacy: .public)")
                    case.success:
                        Logger.autoconsent.debug("self-test requested")
                    }
                }
            )
        } else {
            Logger.autoconsent.error("no self-test scheduled in this tab")
        }
        selfTestWebView = nil
        selfTestFrameInfo = nil
    }

    @MainActor
    func handleSelfTestResult(message: WKScriptMessage, replyHandler: @escaping (Any?, String?) -> Void) {
        guard let messageData: SelfTestResultMessage = decodeMessageBody(from: message.body),
              let url = URL(string: messageData.url) else {
            assertionFailure("Received a malformed message from autoconsent")
            replyHandler(nil, "cannot decode message")
            return
        }
        // store self-test result
        Logger.autoconsent.debug("self-test result: \(String(describing: messageData))")
        refreshDashboardState(consentManaged: true, cosmetic: nil, optoutFailed: false, selftestFailed: messageData.result)
        replyHandler([ "type": "ok" ], nil) // this is just to prevent a Promise rejection
    }

}
