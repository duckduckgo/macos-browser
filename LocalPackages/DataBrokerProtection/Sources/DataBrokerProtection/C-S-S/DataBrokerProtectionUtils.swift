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

@MainActor
final public class DataBrokerUserContentController: WKUserContentController {

    let dataBrokerUserScripts: DataBrokerUserScript

    init(with privacyConfigurationManager: PrivacyConfigurationManaging, prefs: ContentScopeProperties, delegate: CSSCommunicationDelegate) {
        dataBrokerUserScripts = DataBrokerUserScript(privacyConfig: privacyConfigurationManager, prefs: prefs, delegate: delegate)

        super.init()

        dataBrokerUserScripts.userScripts.forEach {
            let userScript = $0.makeWKUserScriptSync()
            self.installUserScripts([userScript], handlers: [$0])
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func installUserScripts(_ wkUserScripts: [WKUserScript], handlers: [UserScript]) {
        handlers.forEach { self.addHandler($0) }
        wkUserScripts.forEach(self.addUserScript)
    }
}

@MainActor
final class DataBrokerUserScript: UserScriptsProvider {
    lazy var userScripts: [UserScript] = [contentScopeUserScriptIsolated]

    let contentScopeUserScriptIsolated: ContentScopeUserScript
    var dataBrokerFeature: DataBrokerProtectionFeature

    init(privacyConfig: PrivacyConfigurationManaging, prefs: ContentScopeProperties, delegate: CSSCommunicationDelegate) {
        contentScopeUserScriptIsolated = ContentScopeUserScript(privacyConfig, properties: prefs, isIsolated: true)
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

@MainActor
extension WKUserContentController {

    func addHandler(_ userScript: UserScript) {
        for messageName in userScript.messageNames {
            if #available(macOS 11.0, *) {
                let contentWorld: WKContentWorld = userScript.getContentWorld()
                if let handlerWithReply = userScript as? WKScriptMessageHandlerWithReply {
                    addScriptMessageHandler(handlerWithReply, contentWorld: contentWorld, name: messageName)
                } else {
                    add(userScript, contentWorld: contentWorld, name: messageName)
                }
            } else {
                add(userScript, name: messageName)
            }
        }
    }
}

extension WKWebViewConfiguration {

    @MainActor
    func applyDataBrokerConfiguration(privacyConfig: PrivacyConfigurationManaging, prefs: ContentScopeProperties, delegate: CSSCommunicationDelegate) {
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
