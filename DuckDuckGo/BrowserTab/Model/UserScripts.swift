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

class UserScripts {

    let faviconScript = FaviconUserScript()
    let html5downloadScript = HTML5DownloadUserScript()
    let contextMenuScript = ContextMenuUserScript()
    let findInPageScript = FindInPageUserScript()
    let contentBlockerScript = ContentBlockerUserScript()
    let contentBlockerRulesScript = ContentBlockerRulesUserScript()
    let debugScript = DebugUserScript()

    lazy var userScripts = [
        self.debugScript,
        self.faviconScript,
        self.html5downloadScript,
        self.contextMenuScript,
        self.findInPageScript,
        self.contentBlockerScript,
        self.contentBlockerRulesScript
    ]

    func install(into webView: WebView) {
        userScripts.forEach {
            webView.configuration.userContentController.add(userScript: $0)
        }
    }

    func remove(from webView: WebView) {
        webView.configuration.userContentController.removeAllUserScripts()
        
        userScripts.forEach {
            $0.messageNames.forEach {
                if #available(OSX 11.0, *) {
                    webView.configuration.userContentController.removeScriptMessageHandler(forName: $0, contentWorld: .defaultClient)
                } else {
                    webView.configuration.userContentController.removeScriptMessageHandler(forName: $0)
                }
            }
        }
    }

}
