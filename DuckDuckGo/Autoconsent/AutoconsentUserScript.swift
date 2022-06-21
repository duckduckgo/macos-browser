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
    func clearCache() {
        dispatchPrecondition(condition: .onQueue(.main))
        sitesNotifiedCache.removeAll()
    }
}

@available(macOS 11, *)
final class AutoconsentUserScript: NSObject, WKScriptMessageHandlerWithReply, UserScriptWithAutoconsent {
    private static var promptLastShown: Date?

    var injectionTime: WKUserScriptInjectionTime { .atDocumentStart }
    var forMainFrameOnly: Bool { false }
    
    enum Constants {
        static let newSitePopupHidden = Notification.Name("newSitePopupHidden")
        static let popupHiddenUrlKey = "popupHiddenUrlKey"
    }
    
    private enum MessageName: String, CaseIterable {
        case `init`
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
        source = Self.loadJS("autoconsent-bundle", from: .main, withReplacements: [:])
        self.config = config
    }

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        // this is never used because macOS <11 is not supported by autoconsent
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

        switch messageName {
        case MessageName.`init`:
            let remoteConfig = self.config.settings(for: .autoconsent)
            let disabledCMPs = remoteConfig["disabledCMPs"] as? [String] ?? []
            let rulesUrl = Bundle.main.url(forResource: "rules", withExtension: "json")!
            let rulesData = (try? Data(contentsOf: rulesUrl))!
            let rules = try? JSONSerialization.jsonObject(with: rulesData, options: [])

            replyHandler([
                "type": "initResp",
                "rules": rules,
                "config": [
                    "enabled": true,
                    "autoAction": "optOut",
                    "disabledCmps": disabledCMPs,
                    "enablePrehide": true
                ]
            ], nil)
        case MessageName.eval:
            let request = (message.body as? [String: Any])!
            let payload = request["code"]!
            let reqId = request["id"]!
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
        case MessageName.popupFound:
            os_log("OLOLO: %s", log: .autoconsent, type: .debug, String(describing: message.body))
        case MessageName.optOutResult:
            os_log("OLOLO: %s", log: .autoconsent, type: .debug, String(describing: message.body))
        case MessageName.optInResult:
            os_log("OLOLO: %s", log: .autoconsent, type: .debug, String(describing: message.body))
        case MessageName.selfTestResult:
            os_log("OLOLO: %s", log: .autoconsent, type: .debug, String(describing: message.body))
        case MessageName.autoconsentDone:
            os_log("OLOLO: %s", log: .autoconsent, type: .debug, String(describing: message.body))
        case MessageName.autoconsentError:
            os_log("OLOLO: %s", log: .autoconsent, type: .debug, String(describing: message.body))
        }
    }

    @MainActor
    func onPageReady(url: URL) {
        let preferences = PrivacySecurityPreferences.shared
        
        guard preferences.autoconsentEnabled != false else {
            os_log("autoconsent is disabled", log: .autoconsent, type: .debug)
            return
        }
        
        // reset dashboard state
//        self.delegate?.autoconsentUserScript(consentStatus: CookieConsentInfo(
//            consentManaged: Self.sitesNotifiedCache.contains(url.host ?? ""), optoutFailed: nil, selftestFailed: nil))

        guard config.isFeature(.autoconsent, enabledForDomain: url.host) else {
            os_log("disabled for site: %s", log: .autoconsent, type: .info, String(describing: url.absoluteString))
            return
        }

        guard url.absoluteString != "about:home" else {
            return
        }

//        Self.background.ready {
//            // push current privacy config settings to the background page
//            Self.background.updateSettings(settings: self.config.settings(for: .autoconsent))
//            let cmp = await Self.background.detectCmp(in: self.tabId)
//            guard let cmp = cmp, cmp.result == true else {
//                os_log("no CMP detected", log: .autoconsent, type: .info)
//                self.actionInProgress = false
//                return
//            }
//            os_log("CMP found: %s", log: .autoconsent, type: .info, String(describing: cmp.ruleName))
//
//            guard await Self.background.isPopupOpen(in: self.tabId) else {
//                os_log("popup not open", log: .autoconsent, type: .debug)
//                self.actionInProgress = false
//                return
//            }
//            os_log("Open popup found: %s", log: .autoconsent, type: .info, String(describing: cmp.ruleName))
//
//            // check if the user has explicitly enabled the feature
//            self.checkUserWasPrompted { enabled in
//                guard enabled else {
//                    self.actionInProgress = false
//                    return
//                }
//                Task {
//                    await self.runOptOut(for: cmp, on: url)
//                }
//            }
//        }
    }

    @MainActor
    func checkUserWasPrompted(callback: @escaping (Bool) -> Void) {
//        let preferences = PrivacySecurityPreferences.shared
//        guard preferences.autoconsentEnabled == nil else {
//            callback(true)
//            return
//        }
//        let now = Date.init()
//        guard Self.promptLastShown == nil || now > Self.promptLastShown!.addingTimeInterval(30),
//              let window = self.webview?.window else {
//            callback(false)
//            return
//        }
//        Self.promptLastShown = now
//        let alert = NSAlert.cookiePopup()
//        alert.beginSheetModal(for: window, completionHandler: { response in
//            switch response {
//            case .alertFirstButtonReturn:
//                // User wants to turn on the feature
//                preferences.autoconsentEnabled = true
//                callback(true)
//            case .alertSecondButtonReturn:
//                // "Not now"
//                callback(false)
//            case .alertThirdButtonReturn:
//                // "Don't ask again"
//                preferences.autoconsentEnabled = false
//                callback(false)
//            case _:
//                callback(false)
//            }
//        })
    }

    @MainActor
    func runOptOut(for cmp: AutoconsentBackground.ActionResponse, on url: URL) async {
//        let optOutSuccessful = await Self.background.doOptOut(in: self.tabId)
//        guard optOutSuccessful else {
//            os_log("opt out failed: %s", log: .autoconsent, type: .error, String(describing: cmp.ruleName))
//            self.delegate?.autoconsentUserScript(consentStatus: CookieConsentInfo(
//                consentManaged: true, optoutFailed: true, selftestFailed: nil))
//            self.actionInProgress = false
//            return
//        }
//        os_log("opted out: %s", log: .autoconsent, type: .info, String(describing: cmp.ruleName))
//        // post popover notification on main thread
//        DispatchQueue.main.async {
//            NotificationCenter.default.post(name: Constants.newSitePopupHidden, object: self, userInfo: [
//                Constants.popupHiddenUrlKey: url
//            ])
//        }
//
//        do {
//            let response = try await Self.background.testOptOutWorked(in: self.tabId)
//            os_log("self test successful?: %s", log: .autoconsent, type: .debug, String(describing: response.result))
//            self.delegate?.autoconsentUserScript(consentStatus: CookieConsentInfo(
//                consentManaged: true, optoutFailed: false, selftestFailed: false))
//        } catch {
//            os_log("self test error: %s", log: .autoconsent, type: .error, error.localizedDescription)
//            self.delegate?.autoconsentUserScript(consentStatus: CookieConsentInfo(
//                consentManaged: true, optoutFailed: false, selftestFailed: true))
//        }
//        self.actionInProgress = false
    }
}
