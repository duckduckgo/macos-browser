//
//  UserScript.swift
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

import Foundation
import WebKit

class UserScript: WKUserScript {

    let messageNames: [String]

    init(source: String, messageNames: [String], injectionTime: WKUserScriptInjectionTime = .atDocumentStart, forMainFrameOnly: Bool = true) {
        self.messageNames = messageNames

        if #available(OSX 11.0, *) {
            super.init(source: source, injectionTime: injectionTime, forMainFrameOnly: forMainFrameOnly, in: .defaultClient)
        } else {
            super.init(source: source, injectionTime: injectionTime, forMainFrameOnly: forMainFrameOnly)
        }
    }

}

extension UserScript: WKScriptMessageHandler {

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        
    }

}
