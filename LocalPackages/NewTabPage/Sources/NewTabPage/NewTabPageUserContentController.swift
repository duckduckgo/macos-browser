//
//  NewTabPageUserContentController.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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
import UserScriptActionsManager
import WebKitExtensions

public final class NewTabPageUserContentController: WKUserContentController {

    private let newTabPageUserScriptProvider: NewTabPageUserScriptProvider

    @MainActor
    public init(newTabPageUserScript: NewTabPageUserScript) {
        newTabPageUserScriptProvider = NewTabPageUserScriptProvider(newTabPageUserScript: newTabPageUserScript)

        super.init()

        newTabPageUserScriptProvider.userScripts.forEach { userScript in
            addHandler(userScript)
            addUserScript(userScript.makeWKUserScriptSync())
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

@MainActor
private final class NewTabPageUserScriptProvider: UserScriptsProvider {
    lazy var userScripts: [UserScript] = [specialPagesUserScript]

    let specialPagesUserScript: SpecialPagesUserScript

    init(newTabPageUserScript: NewTabPageUserScript) {
        specialPagesUserScript = SpecialPagesUserScript()
        specialPagesUserScript.registerSubfeature(delegate: newTabPageUserScript)
    }

    func loadWKUserScripts() async -> [WKUserScript] {
        [await specialPagesUserScript.makeWKUserScript().wkUserScript]
    }
}
