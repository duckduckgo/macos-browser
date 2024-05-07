//
//  UserScripts.swift
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

import Foundation
import BrowserServicesKit
import UserScript
import WebKit
import Subscription

@MainActor
final class UserScripts: UserScriptsProvider {

    let pageObserverScript = PageObserverUserScript()
    let faviconScript = FaviconUserScript()
    let contextMenuScript = ContextMenuUserScript()
    let printingUserScript = PrintingUserScript()
    let hoverUserScript = HoverUserScript()
    let debugScript = DebugUserScript()
    let subscriptionPagesUserScript = SubscriptionPagesUserScript()
    let identityTheftRestorationPagesUserScript = IdentityTheftRestorationPagesUserScript()
    let clickToLoadScript: ClickToLoadUserScript

    let contentBlockerRulesScript: ContentBlockerRulesUserScript
    let surrogatesScript: SurrogatesUserScript
    let contentScopeUserScript: ContentScopeUserScript
    let contentScopeUserScriptIsolated: ContentScopeUserScript
    let autofillScript: WebsiteAutofillUserScript
    let specialPages: SpecialPagesUserScript?
    let autoconsentUserScript: UserScriptWithAutoconsent
    let youtubeOverlayScript: YoutubeOverlayUserScript?
    let youtubePlayerUserScript: YoutubePlayerUserScript?
    let sslErrorPageUserScript: SSLErrorPageUserScript?

    init(with sourceProvider: ScriptSourceProviding) {
        clickToLoadScript = ClickToLoadUserScript(scriptSourceProvider: sourceProvider)
        contentBlockerRulesScript = ContentBlockerRulesUserScript(configuration: sourceProvider.contentBlockerRulesConfig!)
        surrogatesScript = SurrogatesUserScript(configuration: sourceProvider.surrogatesConfig!)

        let isGPCEnabled = WebTrackingProtectionPreferences.shared.isGPCEnabled
        let privacyConfig = sourceProvider.privacyConfigurationManager.privacyConfig
        let sessionKey = sourceProvider.sessionKey ?? ""
        let prefs = ContentScopeProperties(gpcEnabled: isGPCEnabled,
                                                sessionKey: sessionKey,
                                                featureToggles: ContentScopeFeatureToggles.supportedFeaturesOnMacOS(privacyConfig))
        contentScopeUserScript = ContentScopeUserScript(sourceProvider.privacyConfigurationManager, properties: prefs)
        contentScopeUserScriptIsolated = ContentScopeUserScript(sourceProvider.privacyConfigurationManager, properties: prefs, isIsolated: true)

        autofillScript = WebsiteAutofillUserScript(scriptSourceProvider: sourceProvider.autofillSourceProvider!)

        autoconsentUserScript = AutoconsentUserScript(scriptSource: sourceProvider, config: sourceProvider.privacyConfigurationManager.privacyConfig)

        sslErrorPageUserScript = SSLErrorPageUserScript()

        specialPages = SpecialPagesUserScript()

        if DuckPlayer.shared.isAvailable {
            youtubeOverlayScript = YoutubeOverlayUserScript()
            youtubePlayerUserScript = YoutubePlayerUserScript()
        } else {
            youtubeOverlayScript = nil
            youtubePlayerUserScript = nil
        }

        userScripts.append(autoconsentUserScript)

        if let youtubeOverlayScript {
            contentScopeUserScriptIsolated.registerSubfeature(delegate: youtubeOverlayScript)
        }

        if let specialPages = specialPages {
            if let sslErrorPageUserScript {
                specialPages.registerSubfeature(delegate: sslErrorPageUserScript)
            }
            if let youtubePlayerUserScript {
                specialPages.registerSubfeature(delegate: youtubePlayerUserScript)
            }
            userScripts.append(specialPages)
        }

        if DefaultSubscriptionFeatureAvailability().isFeatureAvailable {
            subscriptionPagesUserScript.registerSubfeature(delegate: SubscriptionPagesUseSubscriptionFeature(subscriptionManager: AppDelegate.shared.subscriptionManager))
            userScripts.append(subscriptionPagesUserScript)

            identityTheftRestorationPagesUserScript.registerSubfeature(delegate: IdentityTheftRestorationPagesFeature())
            userScripts.append(identityTheftRestorationPagesUserScript)
        }
    }

    lazy var userScripts: [UserScript] = [
        debugScript,
        faviconScript,
        contextMenuScript,
        surrogatesScript,
        contentBlockerRulesScript,
        pageObserverScript,
        printingUserScript,
        hoverUserScript,
        clickToLoadScript,
        contentScopeUserScript,
        contentScopeUserScriptIsolated,
        autofillScript
    ]

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
