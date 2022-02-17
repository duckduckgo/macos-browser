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
import TrackerRadarKit

final class UserScripts {

    let pageObserverScript = PageObserverUserScript()
    let faviconScript = FaviconUserScript()
    let contextMenuScript = ContextMenuUserScript()
    let findInPageScript = FindInPageUserScript()
    let printingUserScript = PrintingUserScript()
    let hoverUserScript = HoverUserScript()
    let debugScript = DebugUserScript()
    let clickToLoadScript = ClickToLoadUserScript()

    let contentBlockerRulesScript: ContentBlockerRulesUserScript
    let surrogatesScript: SurrogatesUserScript
    let contentScopeUserScript: ContentScopeUserScript
    let autofillScript: AutofillUserScript

    init(with sourceProvider: ScriptSourceProviding) {

        contentBlockerRulesScript = ContentBlockerRulesUserScript(configuration: sourceProvider.contentBlockerRulesConfig!)
        surrogatesScript = SurrogatesUserScript(configuration: sourceProvider.surrogatesConfig!)
        let privacySettings = PrivacySecurityPreferences()
        let sessionKey = sourceProvider.sessionKey ?? ""
        let prefs = ContentScopeProperties.init(gpcEnabled: privacySettings.gpcEnabled, sessionKey: sessionKey)
        contentScopeUserScript = ContentScopeUserScript(sourceProvider.privacyConfigurationManager, properties: prefs)
        autofillScript = AutofillUserScript(scriptSourceProvider: sourceProvider.autofillSourceProvider!)
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

extension UserScripts {

    func install(into controller: WKUserContentController) {
        scripts.forEach(controller.addUserScript)
        userScripts.forEach(controller.addHandler)
    }

    func remove(from controller: WKUserContentController) {
        controller.removeAllUserScripts()
        userScripts.forEach(controller.removeHandler)
    }

}
