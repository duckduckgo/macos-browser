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

    // swiftlint:disable line_length

    let surrogatesScript = SurrogatesUserScript(configurationSource: DefaultSurrogatesUserScriptConfigSource(privacyConfig: ContentBlocking.privacyConfigurationManager.privacyConfig,
                                                                                                             surrogates: DefaultConfigurationStorage.shared.loadData(for: .surrogates)?.utf8String() ?? "", trackerData: ContentBlocking.contentBlockingManager.currentRules?.trackerData, encodedSurrogateTrackerData: ContentBlocking.contentBlockingManager.currentRules?.encodedTrackerData, isDebugBuild: isDebugBuild) )

    let contentBlockerRulesScript = ContentBlockerRulesUserScript(configurationSource: ContentBlockerUserScriptConfigSource(privacyConfiguration: ContentBlocking.privacyConfigurationManager.privacyConfig,
                                                                                                                            trackerData: ContentBlocking.contentBlockingManager.currentRules?.trackerData))
    // swiftlint:enable line_length
    let autofillScript = AutofillUserScript()
    let printingUserScript = PrintingUserScript()
    let hoverUserScript = HoverUserScript()
    let navigatorCredentialsUserScript = NavigatorCredentialsUserScript()
    let debugScript = DebugUserScript()
    let gpcScript = GPCUserScript()

    init() {
    }

    init(copy other: UserScripts) {
        scripts = other.scripts
        scripts.removeLast()
        scripts.append(autofillScript.makeWKUserScript())
    }

    lazy var userScripts: [UserScript] = [
        self.debugScript,
        self.faviconScript,
        self.contextMenuScript,
        self.findInPageScript,
        self.surrogatesScript,
        self.contentBlockerRulesScript,
        self.pageObserverScript,
        self.printingUserScript,
        self.hoverUserScript,
        self.gpcScript,
        self.navigatorCredentialsUserScript,
        self.autofillScript
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
