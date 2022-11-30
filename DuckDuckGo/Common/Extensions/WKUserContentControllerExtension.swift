//
//  WKUserContentControllerExtension.swift
//
//  Copyright © 2020 DuckDuckGo. All rights reserved.
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

import Cocoa
import WebKit
import BrowserServicesKit
import UserScript

extension WKUserContentController {

    func addHandlerNoContentWorld(_ userScript: UserScript) {
        for messageName in userScript.messageNames {
            add(userScript, name: messageName)
        }
    }
    
    func addHandler(_ userScript: UserScript) {
        for messageName in userScript.messageNames {
            if #available(macOS 11.0, *) {
                let contentWorld: WKContentWorld = userScript.getContentWorld()
                if let handlerWithReply = userScript as? WKScriptMessageHandlerWithReply {
                    addScriptMessageHandler(handlerWithReply, contentWorld: contentWorld, name: messageName)
                } else {
                    add(userScript, contentWorld: contentWorld, name: messageName)
                }
            } else {
                add(userScript, name: messageName)
            }
        }
    }

    func removeHandler(_ userScript: UserScript) {
        userScript.messageNames.forEach {
            if #available(macOS 11.0, *) {
                let contentWorld: WKContentWorld = userScript.getContentWorld()
                removeScriptMessageHandler(forName: $0, contentWorld: contentWorld)
            } else {
                removeScriptMessageHandler(forName: $0)
            }
        }
    }

}
