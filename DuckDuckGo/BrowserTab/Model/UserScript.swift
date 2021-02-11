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

    lazy var leakAvoider: LeakAvoider = {
        LeakAvoider(delegate: self)
    }()

    static func loadJS(_ jsFile: String, withReplacements replacements: [String: String] = [:]) -> String {

        let bundle = Bundle.main
        let path = bundle.path(forResource: jsFile, ofType: "js")!

        guard var js = try? String(contentsOfFile: path) else {
            fatalError("Failed to load JavaScript \(jsFile) from \(path)")
        }

        for (key, value) in replacements {
            js = js.replacingOccurrences(of: key, with: value, options: .literal)
        }

        return js
    }

}

extension UserScript: WKScriptMessageHandler {

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        
    }

}

/// Reference: https://stackoverflow.com/questions/26383031/wkwebview-causes-my-view-controller-to-leak/26383032#26383032
///
/// This is only a mitigation of the problem. Instead of scripts themselves leaking, which are far larger in size, the LeakAvoider will be leaked.
/// It can save others from leaking, but not itself.
class LeakAvoider: NSObject, WKScriptMessageHandler {

    weak var delegate: WKScriptMessageHandler?

    init(delegate: WKScriptMessageHandler) {
        self.delegate = delegate
        super.init()
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        self.delegate?.userContentController(userContentController, didReceive: message)
    }

}
