//
//  ClickToLoadUserScript.swift
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

import WebKit
import UserScript
import BrowserServicesKit

protocol ClickToLoadUserScriptDelegate: AnyObject {

    func clickToLoadUserScriptAllowFB(_ script: UserScript, replyHandler: @escaping (Bool) -> Void)
}

final class ClickToLoadUserScript: NSObject, UserScript, WKScriptMessageHandlerWithReply {

    var injectionTime: WKUserScriptInjectionTime { .atDocumentEnd }
    var forMainFrameOnly: Bool { false }
    var messageNames: [String] { ["getImage", "enableFacebook", "initClickToLoad" ] }
    let source: String

    init(scriptSourceProvider: ScriptSourceProviding) {
        self.source = scriptSourceProvider.clickToLoadSource
    }

    weak var delegate: ClickToLoadUserScriptDelegate?

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage,
                               replyHandler: @escaping (Any?, String?) -> Void) {
        if message.name == "initClickToLoad" {
            let host = message.body as? String
            let controller = userContentController as? UserContentController
            let privacyConfigurationManager = controller!.privacyConfigurationManager
            let privacyConfiguration = privacyConfigurationManager.privacyConfig

            let locallyProtected = privacyConfiguration.isProtected(domain: host)
            let featureEnabled = privacyConfiguration.isFeature(.clickToPlay, enabledForDomain: host)
            if locallyProtected && featureEnabled {
                replyHandler(true, nil)
            } else {
                replyHandler(false, nil)
            }
            return
        }
        if message.name == "enableFacebook" {
            guard let delegate = delegate else { return }
            delegate.clickToLoadUserScriptAllowFB(self) { (_) -> Void in
                guard let isLogin = message.body as? Bool else {
                    replyHandler(nil, nil)
                    return
                }

                replyHandler(isLogin, nil)
            }

            return
        }

        var image: String

        guard let arg = message.body as? String else {
            replyHandler(nil, nil)
            return
        }
        if message.name == "getImage" {
            image = ClickToLoadModel.getImage[arg]!
        } else {
            assertionFailure("Uknown message type")
            replyHandler(nil, nil)
            return
        }
        replyHandler(image, nil)
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        assertionFailure("SHOULDN'T BE HERE!")
    }

}
