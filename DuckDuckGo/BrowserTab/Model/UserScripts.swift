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

final class UserScripts {

    let pageObserverScript = PageObserverUserScript()
    let faviconScript = FaviconUserScript()
    let contextMenuScript = ContextMenuUserScript()
    let findInPageScript = FindInPageUserScript()
    let contentBlockerScript = ContentBlockerUserScript()
    let contentBlockerRulesScript = ContentBlockerRulesUserScript()
    let autofillScript = AutofillUserScript()
    let debugScript = DebugUserScript()

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
        self.contentBlockerScript,
        self.contentBlockerRulesScript,
        self.pageObserverScript,
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
