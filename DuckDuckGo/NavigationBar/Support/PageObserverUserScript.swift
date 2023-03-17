//
//  PageObserverUserScript.swift
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

protocol PageObserverUserScriptDelegate: AnyObject {

    func pageDOMLoaded()

}

final class PageObserverUserScript: NSObject, StaticUserScript {

    weak var delegate: PageObserverUserScriptDelegate?

    static var injectionTime: WKUserScriptInjectionTime { .atDocumentEnd }

    static var forMainFrameOnly: Bool { false }

    static let source = """

        // assuming we're inserted at document end, we can message up to the native layer immediately
        webkit.messageHandlers.pageDOMLoaded.postMessage({});

    """

    static var script: WKUserScript = PageObserverUserScript.makeWKUserScript()

    var messageNames: [String] {
        ["pageDOMLoaded"]
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.frameInfo.isMainFrame {
            delegate?.pageDOMLoaded()
        }
    }

}
