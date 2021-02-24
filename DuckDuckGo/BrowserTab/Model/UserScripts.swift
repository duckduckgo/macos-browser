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

class UserScripts {

    let pageObserverScript = PageObserverUserScript()
    let faviconScript = FaviconUserScript()
    let html5downloadScript = HTML5DownloadUserScript()
    let contextMenuScript = ContextMenuUserScript()
    let findInPageScript = FindInPageUserScript()
    let loginDetectionUserScript = LoginFormDetectionUserScript()
    let contentBlockerScript = ContentBlockerUserScript()
    let contentBlockerRulesScript = ContentBlockerRulesUserScript()
    let emailScript = EmailUserScript()
    let debugScript = DebugUserScript()

    init() {
    }

    init(copy other: UserScripts) {
        // copy compiled scripts to avoid repeated loading from disk
        self.scripts = other.scripts
    }

    lazy var userScripts: [UserScript] = [
        self.debugScript,
        self.faviconScript,
        self.html5downloadScript,
        self.contextMenuScript,
        self.findInPageScript,
        self.loginDetectionUserScript,
        self.contentBlockerScript,
        self.contentBlockerRulesScript,
        self.emailScript,
        self.pageObserverScript
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
