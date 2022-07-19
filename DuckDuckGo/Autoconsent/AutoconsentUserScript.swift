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
import os
import BrowserServicesKit

protocol AutoconsentUserScriptDelegate: AnyObject {
    func autoconsentUserScript(consentStatus: CookieConsentInfo)
}

protocol UserScriptWithAutoconsent: UserScript {
    var delegate: AutoconsentUserScriptDelegate? { get set }
}

final class AutoconsentManagement {
    static let shared = AutoconsentManagement()
    var sitesNotifiedCache = Set<String>()
    var promptLastShown: Date?
    func clearCache() {
        dispatchPrecondition(condition: .onQueue(.main))
        sitesNotifiedCache.removeAll()
    }
}

@available(macOS 11, *)
final class AutoconsentUserScript: NSObject, WKScriptMessageHandlerWithReply, UserScriptWithAutoconsent {
    var injectionTime: WKUserScriptInjectionTime { .atDocumentStart }
    var forMainFrameOnly: Bool { false }
    var selfTestWebView: WKWebView?
    var selfTestFrameInfo: WKFrameInfo?
    var topUrl: URL?

    enum Constants {
        static let newSitePopupHidden = Notification.Name("newSitePopupHidden")
    }

    public var messageNames: [String] { MessageName.allCases.map(\.rawValue) }
    let source: String
    private let config: PrivacyConfiguration
    weak var delegate: AutoconsentUserScriptDelegate?

    init(scriptSource: ScriptSourceProviding, config: PrivacyConfiguration) {
        os_log("Initialising autoconsent userscript", log: .autoconsent, type: .debug)
        source = Self.loadJS("autoconsent-bundle", from: .main, withReplacements: [:])
        self.config = config
    }

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        // this is never used because macOS <11 is not supported by autoconsent
    }

    @MainActor
    func refreshDashboardState(consentManaged: Bool, optoutFailed: Bool?, selftestFailed: Bool?) {
        self.delegate?.autoconsentUserScript(consentStatus: CookieConsentInfo(
            consentManaged: consentManaged, optoutFailed: optoutFailed, selftestFailed: selftestFailed)
        )
    }

    @MainActor
    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage,
                               replyHandler: @escaping (Any?, String?) -> Void) {
        os_log("Message received: %s", log: .autoconsent, type: .debug, String(describing: message.body))
        return handleMessage(replyHandler: replyHandler, message: message)
    }
}

@available(macOS 11, *)
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
        let cmp: String
        let url: String
    }
    
    struct OptOutResultMessage: Codable {
        let type: String
        let cmp: String
        let result: Bool
        let scheduleSelfTest: Bool
        let url: String
    }
    
    struct OptInResultMessage: Codable {
        let type: String
        let cmp: String
        let result: Bool
        let scheduleSelfTest: Bool
        let url: String
    }
    
    struct SelfTestResultMessage: Codable {
        let type: String
        let cmp: String
        let result: Bool
        let url: String
    }
    
    struct AutoconsentDoneMessage: Codable {
        let type: String
        let cmp: String
        let url: String
    }
    
    func decodeMessageBody<Input: Any, Target: Codable>(from message: Input) -> Target? {
        do {
            let json = try JSONSerialization.data(withJSONObject: message)
            return try JSONDecoder().decode(Target.self, from: json)
        } catch {
            os_log(.error, "Error decoding message body: %{public}@", error.localizedDescription)
            return nil
        }
    }
}

@available(macOS 11, *)
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
            os_log("ignoring optInResult: %s", log: .autoconsent, type: .debug, String(describing: message.body))
            replyHandler(nil, "opt-in is not supported")
        case MessageName.cmpDetected:
            // no need to do anything here
            replyHandler([ "type": "ok" ], nil) // this is just to prevent a Promise rejection
        case MessageName.selfTestResult:
            handleSelfTestResult(message: message, replyHandler: replyHandler)
        case MessageName.autoconsentDone:
            handleAutoconsentDone(message: message, replyHandler: replyHandler)
        case MessageName.autoconsentError:
            os_log("Autoconsent error: %s", log: .autoconsent, String(describing: message.body))
            replyHandler([ "type": "ok" ], nil) // this is just to prevent a Promise rejection
        }
    }

    @MainActor
    func handleInit(message: WKScriptMessage, replyHandler: @escaping (Any?, String?) -> Void) {
        guard let messageData: InitMessage = decodeMessageBody(from: message.body) else {
            replyHandler(nil, "cannot decode message")
            return
        }
        guard let url = URL(string: messageData.url) else {
            replyHandler(nil, "cannot decode init request")
            return
        }
        if !url.isHttp && !url.isHttps {
            // ignore special schemes
            os_log("Ignoring special URL scheme: %s", log: .autoconsent, type: .debug, messageData.url)
            replyHandler([ "type": "ok" ], nil) // this is just to prevent a Promise rejection
            return
        }
        if PrivacySecurityPreferences.shared.autoconsentEnabled == false {
            // this will only happen if the user has just declined a prompt in this tab
            replyHandler([ "type": "ok" ], nil) // this is just to prevent a Promise rejection
            return
        }

        guard config.isFeature(.autoconsent, enabledForDomain: url.host) else {
            os_log("disabled for site: %s", log: .autoconsent, type: .info, String(describing: url.absoluteString))
            replyHandler([ "type": "ok" ], nil) // this is just to prevent a Promise rejection
            return
        }

        if message.frameInfo.isMainFrame {
            topUrl = url
            // reset dashboard state
            refreshDashboardState(
                consentManaged: AutoconsentManagement.shared.sitesNotifiedCache.contains(url.host ?? ""),
                optoutFailed: nil,
                selftestFailed: nil
            )
        }
        let remoteConfig = self.config.settings(for: .autoconsent)
        let disabledCMPs = remoteConfig["disabledCMPs"] as? [String] ?? []

        replyHandler([
            "type": "initResp",
            "rules": nil, // rules are bundled with the content script atm
            "config": [
                "enabled": true,
                // if it's the first time, disable autoAction
                "autoAction": PrivacySecurityPreferences.shared.autoconsentEnabled == true ? "optOut" : nil,
                "disabledCmps": disabledCMPs,
                // the very first time, make sure the popup is visible
                "enablePrehide": PrivacySecurityPreferences.shared.autoconsentEnabled,
                "detectRetries": 20
            ]
        ], nil)
    }
    
    @MainActor
    func handleEval(message: WKScriptMessage, replyHandler: @escaping (Any?, String?) -> Void) {
        guard let messageData: EvalMessage = decodeMessageBody(from: message.body) else {
            replyHandler(nil, "cannot decode message")
            return
        }
        let script = """
        (() => {
        try {
            return !!(\(messageData.code))
        } catch (e) {
          // ignore CSP errors
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
        guard PrivacySecurityPreferences.shared.autoconsentEnabled == nil else {
            // if feature is already enabled, opt-out will happen automatically
            replyHandler([ "type": "ok" ], nil) // this is just to prevent a Promise rejection
            return
        }
        
        os_log("Prompting user about autoconsent", log: .autoconsent, type: .debug)

        // if it's the first time, prompt the user and trigger opt-out
        if let window = message.webView?.window {
            ensurePrompt(window: window, callback: { shouldProceed in
                if shouldProceed {
                    Task {
                        replyHandler([ "type": "optOut" ], nil)
                    }
                }
            })
        } else {
            replyHandler(nil, "missing frame target")
        }
    }
    
    @MainActor
    func handleOptOutResult(message: WKScriptMessage, replyHandler: @escaping (Any?, String?) -> Void) {
        guard let messageData: OptOutResultMessage = decodeMessageBody(from: message.body) else {
            replyHandler(nil, "cannot decode message")
            return
        }
        os_log("opt-out result: %s", log: .autoconsent, type: .debug, String(describing: messageData))

        if !messageData.result {
            refreshDashboardState(consentManaged: true, optoutFailed: true, selftestFailed: nil)
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
        guard let messageData: AutoconsentDoneMessage = decodeMessageBody(from: message.body) else {
            replyHandler(nil, "cannot decode message")
            return
        }
        os_log("opt-out successful: %s", log: .autoconsent, type: .debug, String(describing: messageData))
        
        guard let url = URL(string: messageData.url),
              let host = url.host else {
            replyHandler(nil, "cannot decode message")
            return
        }
        
        refreshDashboardState(consentManaged: true, optoutFailed: false, selftestFailed: nil)
        
        // trigger popup once per domain
        if !AutoconsentManagement.shared.sitesNotifiedCache.contains(host) {
            os_log("bragging that we closed a popup", log: .autoconsent, type: .debug)
            AutoconsentManagement.shared.sitesNotifiedCache.insert(host)
            // post popover notification on main thread
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Constants.newSitePopupHidden, object: self, userInfo: [
                    "topUrl": self.topUrl ?? url
                ])
            }
        }
        
        replyHandler([ "type": "ok" ], nil) // this is just to prevent a Promise rejection

        if let selfTestWebView = selfTestWebView,
           let selfTestFrameInfo = selfTestFrameInfo {
            os_log("requesting self-test in: %s", log: .autoconsent, type: .debug, messageData.url)
            selfTestWebView.evaluateJavaScript(
                "window.autoconsentMessageCallback({ type: 'selfTest' })",
                in: selfTestFrameInfo,
                in: WKContentWorld.defaultClient,
                completionHandler: { (result) in
                    switch result {
                    case.failure(let error):
                        os_log("Error running self-test: %s", log: .autoconsent, type: .debug, String(describing: error))
                    case.success:
                        os_log("self-test requested", log: .autoconsent, type: .debug)
                    }
                }
            )
        } else {
            os_log("no self-test scheduled in this tab", log: .autoconsent, type: .debug)
        }
        selfTestWebView = nil
        selfTestFrameInfo = nil
    }
    
    @MainActor
    func handleSelfTestResult(message: WKScriptMessage, replyHandler: @escaping (Any?, String?) -> Void) {
        guard let messageData: SelfTestResultMessage = decodeMessageBody(from: message.body) else {
            replyHandler(nil, "cannot decode message")
            return
        }
        // store self-test result
        os_log("self-test result: %s", log: .autoconsent, type: .debug, String(describing: messageData))
        refreshDashboardState(consentManaged: true, optoutFailed: false, selftestFailed: messageData.result)
        replyHandler([ "type": "ok" ], nil) // this is just to prevent a Promise rejection
    }

    @MainActor
    func ensurePrompt(window: NSWindow, callback: @escaping (Bool) -> Void) {
        let preferences = PrivacySecurityPreferences.shared
        let now = Date.init()
        guard AutoconsentManagement.shared.promptLastShown == nil || now > AutoconsentManagement.shared.promptLastShown!.addingTimeInterval(30) else {
            // user said "not now" recently, don't bother asking
            os_log("Have a recent user response, canceling prompt", log: .autoconsent, type: .debug)
            callback(preferences.autoconsentEnabled ?? false) // if two prompts were scheduled from the same tab, result could be true
            return
        }

        AutoconsentManagement.shared.promptLastShown = now
        let alert = NSAlert.cookiePopup()
        alert.beginSheetModal(for: window, completionHandler: { response in
            switch response {
            case .alertFirstButtonReturn:
                // User wants to turn on the feature
                preferences.autoconsentEnabled = true
                callback(true)
            case .alertSecondButtonReturn:
                // "Not now"
                callback(false)
            case .alertThirdButtonReturn:
                // "Don't ask again"
                preferences.autoconsentEnabled = false
                callback(false)
            case _:
                callback(false)
            }
        })
    }
}
