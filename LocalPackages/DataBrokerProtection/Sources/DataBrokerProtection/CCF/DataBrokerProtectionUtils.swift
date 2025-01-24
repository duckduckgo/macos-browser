//
//  DataBrokerProtectionUtils.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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
import Foundation
import WebKit
import BrowserServicesKit
import UserScript
import os.log
import Combine

final class DataBrokerUserContentController: WKUserContentController {

    @MainActor
    var dataBrokerUserScripts: DataBrokerUserScript?

    @MainActor
    init(with privacyConfigurationManager: PrivacyConfigurationManaging, prefs: ContentScopeProperties, delegate: CCFCommunicationDelegate) {
        dataBrokerUserScripts = DataBrokerUserScript(privacyConfig: privacyConfigurationManager, prefs: prefs, delegate: delegate)

        super.init()

        dataBrokerUserScripts?.userScripts.forEach {
            let userScript = $0.makeWKUserScriptSync()
            self.installUserScripts([userScript], handlers: [$0])
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @MainActor
    private func installUserScripts(_ wkUserScripts: [WKUserScript], handlers: [UserScript]) {
        handlers.forEach { self.addHandler($0) }
        wkUserScripts.forEach(self.addUserScript)
    }

    @MainActor
    public func cleanUpBeforeClosing() {
        Logger.dataBrokerProtection.log("Cleaning up DBP user scripts")

        self.removeAllUserScripts()
        self.removeAllScriptMessageHandlers()

        self.removeAllContentRuleLists()
        dataBrokerUserScripts = nil
    }

    deinit {
        Logger.dataBrokerProtection.log("DataBrokerUserContentController Deinit")
    }
}

@MainActor
final class DataBrokerUserScript: UserScriptsProvider {
    lazy var userScripts: [UserScript] = [contentScopeUserScriptIsolated]

    let contentScopeUserScriptIsolated: ContentScopeUserScript
    var dataBrokerFeature: DataBrokerProtectionFeature

    init(privacyConfig: PrivacyConfigurationManaging, prefs: ContentScopeProperties, delegate: CCFCommunicationDelegate) {
        contentScopeUserScriptIsolated = ContentScopeUserScript(privacyConfig.withDataBrokerProtectionFeatureOverride,
                                                                properties: prefs,
                                                                isIsolated: true)
        dataBrokerFeature = DataBrokerProtectionFeature(delegate: delegate)
        dataBrokerFeature.broker = contentScopeUserScriptIsolated.broker
        contentScopeUserScriptIsolated.registerSubfeature(delegate: dataBrokerFeature)
    }

    @MainActor
    func loadWKUserScripts() async -> [WKUserScript] {
        return await withTaskGroup(of: WKUserScriptBox.self) { @MainActor group in
            var wkUserScripts = [WKUserScript]()
            userScripts.forEach { userScript in
                group.addTask { @MainActor in
                    await userScript.makeWKUserScript()
                }
            }
            for await result in group {
                wkUserScripts.append(result.wkUserScript)
            }

            return wkUserScripts
        }
    }
}

final class WebViewSchemeHandler: NSObject, WKURLSchemeHandler {

    static let dataBrokerProtectionScheme = "dbp"

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        let request = urlSchemeTask.request
        let response = URLResponse(url: request.url!, mimeType: "text/plain", expectedContentLength: 200, textEncodingName: nil)
        let responseData = "This is a simulated response".data(using: .utf8)!
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(responseData)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}
}

@MainActor
extension WKUserContentController {

    func addHandler(_ userScript: UserScript) {
        for messageName in userScript.messageNames {
            let contentWorld: WKContentWorld = userScript.getContentWorld()
            if let handlerWithReply = userScript as? WKScriptMessageHandlerWithReply {
                addScriptMessageHandler(handlerWithReply, contentWorld: contentWorld, name: messageName)
            } else {
                add(userScript, contentWorld: contentWorld, name: messageName)
            }
        }
    }
}

extension WKWebViewConfiguration {

    @MainActor
    func applyDataBrokerConfiguration(privacyConfig: PrivacyConfigurationManaging, prefs: ContentScopeProperties, delegate: CCFCommunicationDelegate) {
        setURLSchemeHandler(WebViewSchemeHandler(), forURLScheme: WebViewSchemeHandler.dataBrokerProtectionScheme)
        preferences.isFraudulentWebsiteWarningEnabled = false
        let userContentController = DataBrokerUserContentController(with: privacyConfig, prefs: prefs, delegate: delegate)
        self.userContentController = userContentController
     }
}

extension WKWebView {
    func load(_ url: URL) {
        // Occasionally, the web view will try to load a URL but will find itself with no cookies, even if they've been restored.
        // The consumeCookies call is finishing before this line executes, but if you're fast enough it can happen that WKWebView still hasn't
        // processed the cookies that have been set. Pushing the load to the next iteration of the run loops seems to fix this most of the time.
        DispatchQueue.main.async {
            let request = URLRequest(url: url)
            self.load(request)
        }
    }
}

/// This function applies an override for the Data Broker Protection (DBP) feature.
/// The override is necessary because we only want to inject the DBP feature into detached webViews.
/// These detached webviews are the ones that run the DBP code inside, and we don't want to enable this feature in standard webViews inside the browser.
private extension PrivacyConfigurationManaging {
    var withDataBrokerProtectionFeatureOverride: PrivacyConfigurationManaging {
        return PrivacyConfigurationDataBrokerProtectionConfigOverride(manager: self)
    }
}

private class PrivacyConfigurationDataBrokerProtectionConfigOverride: PrivacyConfigurationManaging {
    var base: Data
    var updatesPublisher: AnyPublisher<(), Never>
    var privacyConfig: PrivacyConfiguration
    var internalUserDecider: InternalUserDecider

    var currentConfig: Data {
        return updateConfigWithBrokerProtection()
    }

    func reload(etag: String?, data: Data?) -> PrivacyConfigurationManager.ReloadResult {
        fatalError("reload(etag:data:) has not been implemented")
    }

    init(manager: PrivacyConfigurationManaging) {
        base = manager.currentConfig
        updatesPublisher = manager.updatesPublisher
        privacyConfig = manager.privacyConfig
        internalUserDecider = manager.internalUserDecider
    }

    private func updateConfigWithBrokerProtection() -> Data {
        let jsonOverride = getJsonOverride()

        guard var original = try? JSONSerialization.jsonObject(with: base, options: []) as? [String: Any],
              let override = try? JSONSerialization.jsonObject(with: jsonOverride, options: []) as? [String: Any],
              var features = original["features"] as? [String: Any] else {
            print("Couldn't deserialize the config")
            return base
        }

        features["brokerProtection"] = override
        original["features"] = features

        return (try? JSONSerialization.data(withJSONObject: original, options: [])) ?? base
    }

    private func getJsonOverride() -> Data {
        return """
        {
          "exceptions": [],
          "state": "enabled",
          "settings": {}
        }
        """.data(using: .utf8)!
    }
}
