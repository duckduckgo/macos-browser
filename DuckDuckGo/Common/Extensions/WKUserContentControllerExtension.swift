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

extension WKUserContentController {

    func addHandler(_ userScript: UserScript) {
        for messageName in userScript.messageNames {
            if #available(OSX 11.0, *) {
                add(userScript, contentWorld: .defaultClient, name: messageName)
            } else {
                add(userScript, name: messageName)
            }
        }
    }

    func removeHandler(_ userScript: UserScript) {
        userScript.messageNames.forEach {
            if #available(OSX 11.0, *) {
                removeScriptMessageHandler(forName: $0, contentWorld: .defaultClient)
            } else {
                removeScriptMessageHandler(forName: $0)
            }
        }
    }

}
