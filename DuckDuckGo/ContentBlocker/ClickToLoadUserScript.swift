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
import BrowserServicesKit

protocol ClickToLoadUserScriptDelegate: AnyObject {

    func clickToLoadUserScriptAllowFB(_ script: UserScript, replyHandler: @escaping (Bool) -> Void) -> Void
}

final class ClickToLoadUserScript: NSObject, UserScript, WKScriptMessageHandlerWithReply {

    struct ContentBlockerKey {
        static let url = "url"
        static let resourceType = "resourceType"
        static let blocked = "blocked"
        static let pageUrl = "pageUrl"
    }

    var injectionTime: WKUserScriptInjectionTime { .atDocumentStart }
    var forMainFrameOnly: Bool { false }
    var messageNames: [String] { ["getImage", "getLogo", "getLoadingImage", "enableFacebook" ] }
    let source: String

    init(scriptSource: ScriptSourceProviding = DefaultScriptSourceProvider.shared) {
        source = scriptSource.clickToLoadSource
    }

    weak var delegate: ClickToLoadUserScriptDelegate?

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage,
                               replyHandler: @escaping (Any?, String?) -> Void) {
        if message.name == "enableFacebook" {
            guard let delegate = delegate else { return }
            delegate.clickToLoadUserScriptAllowFB(self) { (result) -> Void in
                guard let isLogin = message.body as? Bool else {
                    replyHandler(nil, nil)
                    return
                }

                replyHandler(true, nil)
            }

            return
        }
        
        let pathPrefix = "social_images/"
        var fileName: String = ""
        var fileExt: String = ""

        guard let arg = message.body as? String else {
            replyHandler(nil, nil)
            return
        }
        if message.name == "getLoadingImage" {
            switch arg {
            case "light": fileName = "loading_light"
            case "dark" : fileName = "loading_dark"
            default: replyHandler(nil, "Missing loading image namek")
                return
            }
            fileExt = "svg"
        } else if message.name == "getImage" {
            let fileArgs = arg.split(separator: ".")
            fileName = String(fileArgs[0])
            fileExt = String(fileArgs[1])
        } else if message.name == "getLogo" {
            fileName = "dax"
            fileExt = "png"
        } else {
            print("Uknown message type")
            replyHandler(nil, nil)
            return
        }

        let filePath = pathPrefix + fileName

        let imgURL = Bundle.main.url(
            forResource: filePath,
            withExtension: fileExt
        )
        if imgURL == nil {
            replyHandler(nil, "Image not found")
            return
        }
        let base64String = try? Data(contentsOf: imgURL!).base64EncodedString()
        let image = "data:image/" + (fileExt == "svg" ? "svg+xml" : fileExt) + ";base64," + base64String!
        replyHandler(image, nil)
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        print("SHOULDN'T BE HERE!")
    }
}

