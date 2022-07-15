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
        guard let messageName = MessageName(rawValue: message.name) else {
            replyHandler(nil, "Unknown message type")
            return
        }
        
        guard let messageData = message.body as? [String: Any] else {
            replyHandler(nil, "cannot decode message")
            return
        }

        return handleMessage(messageName: messageName, messageData: messageData, replyHandler: replyHandler, message: message)
    }
}

@available(macOS 11, *)
extension AutoconsentUserScript {
    @MainActor
    func handleMessage(messageName: MessageName,
                       messageData: [String: Any],
                       replyHandler: @escaping (Any?, String?) -> Void,
                       message: WKScriptMessage) {
        switch messageName {
        case MessageName.`init`:
            handleInit(messageData: messageData, replyHandler: replyHandler, message: message)
        case MessageName.eval:
            handleEval(messageData: messageData, replyHandler: replyHandler, message: message)
        case MessageName.popupFound:
            handlePopupFound(messageData: messageData, replyHandler: replyHandler, message: message)
        case MessageName.optOutResult:
            handleOptOutResult(messageData: messageData, replyHandler: replyHandler, message: message)
        case MessageName.optInResult:
            // this is not supported in browser
            os_log("ignoring optInResult: %s", log: .autoconsent, type: .debug, String(describing: message.body))
            replyHandler(nil, "opt-in is not supported")
        case MessageName.cmpDetected:
            // no need to do anything here
            replyHandler([ "type": "ok" ], nil) // this is just to prevent a Promise rejection
        case MessageName.selfTestResult:
            handleSelfTestResult(messageData: messageData, replyHandler: replyHandler)
        case MessageName.autoconsentDone:
            handleAutoconsentDone(messageData: messageData, replyHandler: replyHandler)
        case MessageName.autoconsentError:
            os_log("Autoconsent error: %s", log: .autoconsent, String(describing: message.body))
            replyHandler([ "type": "ok" ], nil) // this is just to prevent a Promise rejection
        }
    }
    
    @MainActor
    func handleInit(messageData: [String: Any], replyHandler: @escaping (Any?, String?) -> Void, message: WKScriptMessage) {
        guard let urlString = messageData["url"] as? String,
              let url = URL(string: urlString) else {
            replyHandler(nil, "cannot decode init request")
            return
        }
        if !url.isHttp && !url.isHttps {
            // ignore special schemes
            os_log("Ignoring special URL scheme: %s", log: .autoconsent, type: .debug, urlString)
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
    func handleEval(messageData: [String: Any], replyHandler: @escaping (Any?, String?) -> Void, message: WKScriptMessage) {
        guard let payload = messageData["code"],
              let reqId = messageData["id"] else {
            replyHandler(nil, "cannot decode eval request")
            return
        }
        let script = """
        (() => {
        try {
            console.log("EXEC", `\(payload)`);
            return !!(\(payload))
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
                            "id": reqId,
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
    func handlePopupFound(messageData: [String: Any], replyHandler: @escaping (Any?, String?) -> Void, message: WKScriptMessage) {
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
    func handleOptOutResult(messageData: [String: Any], replyHandler: @escaping (Any?, String?) -> Void, message: WKScriptMessage) {
        os_log("opt-out result: %s", log: .autoconsent, type: .debug, String(describing: messageData))
        guard let scheduleSelfTest = messageData["scheduleSelfTest"] as? Bool,
              let result = messageData["result"] as? Bool else {
            replyHandler(nil, "cannot decode message")
            return
        }

        if !result {
            refreshDashboardState(consentManaged: true, optoutFailed: true, selftestFailed: nil)
        } else if scheduleSelfTest {
            // save a reference to the webview and frame for self-test
            selfTestWebView = message.webView
            selfTestFrameInfo = message.frameInfo
        }

        replyHandler([ "type": "ok" ], nil) // this is just to prevent a Promise rejection
    }
    
    @MainActor
    func handleAutoconsentDone(messageData: [String: Any], replyHandler: @escaping (Any?, String?) -> Void) {
        // report a managed popup
        os_log("opt-out successful: %s", log: .autoconsent, type: .debug, String(describing: messageData))
        
        guard let urlString = messageData["url"] as? String,
              let url = URL(string: urlString),
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
            os_log("requesting self-test in: %s", log: .autoconsent, type: .debug, urlString)
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
    func handleSelfTestResult(messageData: [String: Any], replyHandler: @escaping (Any?, String?) -> Void) {
        // store self-test result
        os_log("self-test result: %s", log: .autoconsent, type: .debug, String(describing: messageData))
        guard let result = messageData["result"] as? Bool else {
            replyHandler(nil, "cannot decode message")
            return
        }
        refreshDashboardState(consentManaged: true, optoutFailed: false, selftestFailed: result)
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
