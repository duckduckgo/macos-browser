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

import os
import Foundation
import BrowserServicesKit
import TrackerRadarKit

final class UserScripts {

    let pageObserverScript = PageObserverUserScript()
    let faviconScript = FaviconUserScript()
    let contextMenuScript = ContextMenuUserScript()
    let findInPageScript = FindInPageUserScript()
    let printingUserScript = PrintingUserScript()
    let hoverUserScript = HoverUserScript()
    let debugScript = DebugUserScript()
    let clickToLoadScript: ClickToLoadUserScript

    let contentBlockerRulesScript: ContentBlockerRulesUserScript
    let surrogatesScript: SurrogatesUserScript
    let contentScopeUserScript: ContentScopeUserScript
    let autofillScript: WebsiteAutofillUserScript
    let autoconsentUserScript: UserScriptWithAutoconsent?
    let youtubeOverlayScript: YoutubeOverlayUserScript?
    let youtubePlayerUserScript: YoutubePlayerUserScript?

    init(with sourceProvider: ScriptSourceProviding) {
        clickToLoadScript = ClickToLoadUserScript(scriptSourceProvider: sourceProvider)
        contentBlockerRulesScript = ContentBlockerRulesUserScript(configuration: sourceProvider.contentBlockerRulesConfig!)
        surrogatesScript = SurrogatesUserScript(configuration: sourceProvider.surrogatesConfig!)
        let privacySettings = PrivacySecurityPreferences.shared
        let sessionKey = sourceProvider.sessionKey ?? ""
        let prefs = ContentScopeProperties.init(gpcEnabled: privacySettings.gpcEnabled,
                                                sessionKey: sessionKey,
                                                featureToggles: ContentScopeFeatureToggles.supportedFeaturesOnMacOS)
        contentScopeUserScript = ContentScopeUserScript(sourceProvider.privacyConfigurationManager, properties: prefs)
        autofillScript = WebsiteAutofillUserScript(scriptSourceProvider: sourceProvider.autofillSourceProvider!)
        if #available(macOS 11, *) {
            autoconsentUserScript = AutoconsentUserScript(scriptSource: sourceProvider,
                                                          config: sourceProvider.privacyConfigurationManager.privacyConfig)
        } else {
            autoconsentUserScript = nil
        }

        if PrivatePlayer.shared.isAvailable {
            youtubeOverlayScript = YoutubeOverlayUserScript()
            youtubePlayerUserScript = YoutubePlayerUserScript()
        } else {
            youtubeOverlayScript = nil
            youtubePlayerUserScript = nil
        }

        if let autoconsentUserScript = autoconsentUserScript {
            userScripts.append(autoconsentUserScript)
        }
        if let youtubeOverlayScript = youtubeOverlayScript {
            userScripts.append(youtubeOverlayScript)
        }
        if let youtubePlayerUserScript = youtubePlayerUserScript {
            userScripts.append(youtubePlayerUserScript)
        }
    }

    lazy var userScripts: [UserScript] = [
        debugScript,
        faviconScript,
        contextMenuScript,
        findInPageScript,
        surrogatesScript,
        contentBlockerRulesScript,
        pageObserverScript,
        printingUserScript,
        hoverUserScript,
        clickToLoadScript,
        contentScopeUserScript,
        autofillScript
    ]

    lazy var scripts = userScripts.map { $0.makeWKUserScript() }

}
