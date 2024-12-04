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
import UserScript
import WebKitExtensions

public final class NewTabPageUserContentController: WKUserContentController {

    public let newTabPageUserScriptProvider: NewTabPageUserScriptProvider

    @MainActor
    public init(newTabPageUserScript: NewTabPageUserScript) {
        newTabPageUserScriptProvider = NewTabPageUserScriptProvider(newTabPageUserScript: newTabPageUserScript)

        super.init()

        newTabPageUserScriptProvider.userScripts.forEach {
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
}

@MainActor
public final class NewTabPageUserScriptProvider: UserScriptsProvider {
    public lazy var userScripts: [UserScript] = [specialPagesUserScript]

    public let specialPagesUserScript: SpecialPagesUserScript

    public init(newTabPageUserScript: NewTabPageUserScript) {
        specialPagesUserScript = SpecialPagesUserScript()
        specialPagesUserScript.registerSubfeature(delegate: newTabPageUserScript)
    }

    @MainActor
    public func loadWKUserScripts() async -> [WKUserScript] {
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
