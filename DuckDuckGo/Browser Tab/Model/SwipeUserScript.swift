//
//  SwipeUserScript.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

import BrowserServicesKit
import WebKit

protocol SwipeUserScriptDelegate: AnyObject {
    func swipeUserScriptDidDetectSwipeBack(_ swipeUserScript: SwipeUserScript)
}

final class SwipeUserScript: NSObject, UserScript {

    public weak var delegate: SwipeUserScriptDelegate?

    public var source: String = """
(function() {

}) ();
"""

    public var injectionTime: WKUserScriptInjectionTime = .atDocumentStart
    public var forMainFrameOnly: Bool = true
    public var messageNames: [String] = ["swipeBackHandler"]

    private(set) var lastURL: URL?

    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == messageNames[0] {
            delegate?.swipeUserScriptDidDetectSwipeBack(self)
        }
    }

}
