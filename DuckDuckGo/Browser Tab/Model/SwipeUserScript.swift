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
import Combine
import WebKit

final class SwipeUserScript: NSObject, UserScript {

    private(set) lazy var source: String = SwipeUserScript.loadJS("swipe", from: .main)

    let injectionTime: WKUserScriptInjectionTime = .atDocumentStart
    let forMainFrameOnly: Bool = true
    let messageNames: [String] = ["swipeBack", "swipeForward"]

    let swipeBackPublisher: AnyPublisher<Void, Never>
    let swipeForwardPublisher: AnyPublisher<Void, Never>
    var isEnabled: Bool = true

    private let swipeBackSubject = PassthroughSubject<Void, Never>()
    private let swipeForwardSubject = PassthroughSubject<Void, Never>()

    override init() {
        swipeBackPublisher = swipeBackSubject
            .throttle(for: 1, scheduler: DispatchQueue.main, latest: false)
            .eraseToAnyPublisher()

        swipeForwardPublisher = swipeForwardSubject
            .throttle(for: 1, scheduler: DispatchQueue.main, latest: false)
            .eraseToAnyPublisher()

        super.init()
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard isEnabled else {
            return
        }

        switch message.name {
        case "swipeBack":
            swipeBackSubject.send()
        case "swipeForward":
            swipeForwardSubject.send()
        default:
            break
        }
    }

}
