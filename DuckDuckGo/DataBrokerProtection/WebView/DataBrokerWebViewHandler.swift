//
//  DataBrokerWebViewHandler.swift
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
import Common

@MainActor
final class DataBrokerWebViewHandler {
    var webView: WKWebView
    let contentScopeUserScript: ContentScopeUserScript
    let userScripts: [UserScript]
    let webViewConfiguration: WKWebViewConfiguration
    let userContentController: DataBrokerUserContentController?

    internal init() {
        let privacySettings = PrivacySecurityPreferences.shared
        let sessionKey =  UUID().uuidString
        let privacyFeatures = PrivacyFeatures

        let prefs = ContentScopeProperties.init(gpcEnabled: privacySettings.gpcEnabled,
                                                sessionKey: sessionKey,
                                                featureToggles: ContentScopeFeatureToggles.supportedFeaturesOnMacOS)

        contentScopeUserScript = ContentScopeUserScript(privacyFeatures.contentBlocking.privacyConfigurationManager,
                                                        properties: prefs,
                                                        isolated: true)

        contentScopeUserScript.registerSubFeature(delegate: DataBrokerMessaging())

        userScripts = [contentScopeUserScript]

        let configuration = WKWebViewConfiguration()
        configuration.applyDataBrokerConfiguration(contentBlocking: privacyFeatures.contentBlocking)
        self.webViewConfiguration = configuration

        let userContentController = configuration.userContentController as? DataBrokerUserContentController
        assert(userContentController != nil)
        self.userContentController = userContentController

        webView = WebView(frame: CGRect(origin: .zero, size: CGSize(width: 1024, height: 1024)), configuration: configuration)
        //userContentController?.delegate = self

    }

    func setupWebView() async {
        let privacyFeatures = PrivacyFeatures

        let userScripts = await loadWKUserScripts()
        let privacySettings = PrivacySecurityPreferences.shared

        let controller = WKUserContentController()

        let userController = UserContentController(assetsPublisher: privacyFeatures.contentBlocking.contentBlockingAssetsPublisher,
                                                   privacyConfigurationManager: privacyFeatures.contentBlocking.privacyConfigurationManager)
        userController.delegate = self
        userScripts.forEach {
            controller.addUserScript($0)
        }

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = userController
        configuration.websiteDataStore = .nonPersistent()

        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1024, height: 1024), configuration: configuration)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1024, height: 1024), styleMask: [.titled],
            backing: .buffered, defer: false
        )
        window.title = "Debug"
        window.contentView = self.webView
        window.makeKeyAndOrderFront(nil)
        print("DONE")

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

    func test() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1024, height: 1024), styleMask: [.titled],
            backing: .buffered, defer: false
        )
        window.title = "Debug"
        window.contentView = self.webView
        window.makeKeyAndOrderFront(nil)

        print("LOAD")
        webView.load(URLRequest(url: URL(string: "https://www.example.com")!))
        print("Test")
    }
}

extension DataBrokerWebViewHandler: UserContentControllerDelegate {
    @MainActor

    func userContentController(_ userContentController: UserContentController, didInstallContentRuleLists contentRuleLists: [String: WKContentRuleList], userScripts: UserScriptsProvider, updateEvent: ContentBlockerRulesManager.UpdateEvent) {
        os_log("DBP: didInstallContentRuleLists", log: .contentBlocking, type: .info)
        guard let userScripts = userScripts as? UserScripts else { fatalError("Unexpected UserScripts") }

    }


}
