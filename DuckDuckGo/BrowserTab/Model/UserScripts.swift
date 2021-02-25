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

final class UserScripts {

    let faviconScript: FaviconUserScript
    let html5downloadScript: HTML5DownloadUserScript
    let contextMenuScript: ContextMenuUserScript
    let findInPageScript: FindInPageUserScript
    let loginDetectionUserScript: LoginFormDetectionUserScript
    let contentBlockerScript: ContentBlockerUserScript
    let contentBlockerRulesScript: ContentBlockerRulesUserScript
    let debugScript: DebugUserScript

    convenience init() {
        self.init(faviconScript: FaviconUserScript(),
                  html5downloadScript: HTML5DownloadUserScript(),
                  contextMenuScript: ContextMenuUserScript(),
                  findInPageScript: FindInPageUserScript(),
                  loginDetectionUserScript: LoginFormDetectionUserScript(),
                  contentBlockerScript: ContentBlockerUserScript(),
                  contentBlockerRulesScript: ContentBlockerRulesUserScript(),
                  debugScript: DebugUserScript())
    }

    private init(faviconScript: FaviconUserScript,
                 html5downloadScript: HTML5DownloadUserScript,
                 contextMenuScript: ContextMenuUserScript,
                 findInPageScript: FindInPageUserScript,
                 loginDetectionUserScript: LoginFormDetectionUserScript,
                 contentBlockerScript: ContentBlockerUserScript,
                 contentBlockerRulesScript: ContentBlockerRulesUserScript,
                 debugScript: DebugUserScript) {

        self.faviconScript = faviconScript
        self.html5downloadScript = html5downloadScript
        self.contextMenuScript = contextMenuScript
        self.findInPageScript = findInPageScript
        self.loginDetectionUserScript = loginDetectionUserScript
        self.contentBlockerScript = contentBlockerScript
        self.contentBlockerRulesScript = contentBlockerRulesScript
        self.debugScript = debugScript
    }

    lazy var userScripts: [UserScript] = [
        self.debugScript,
        self.faviconScript,
        self.html5downloadScript,
        self.contextMenuScript,
        self.findInPageScript,
        self.loginDetectionUserScript,
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
            webView.configuration.userContentController.removeScriptMessageHandlers(forNames: $0.messageNames)
        }
    }

}

extension UserScripts: NSCopying {

    func copy(with zone: NSZone? = nil) -> Any {
        return UserScripts(faviconScript: faviconScript.makeCopy(),
                           html5downloadScript: html5downloadScript.makeCopy(),
                           contextMenuScript: contextMenuScript.makeCopy(),
                           findInPageScript: findInPageScript.makeCopy(),
                           loginDetectionUserScript: loginDetectionUserScript.makeCopy(),
                           contentBlockerScript: contentBlockerScript.makeCopy(),
                           contentBlockerRulesScript: contentBlockerRulesScript.makeCopy(),
                           debugScript: debugScript.makeCopy())
    }

}
