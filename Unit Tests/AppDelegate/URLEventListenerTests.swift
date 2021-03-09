//
//  URLEventListenerTests.swift
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

import XCTest
@testable import DuckDuckGo_Privacy_Browser

class URLEventListenerTests: XCTestCase {

    func test() {
        assertUrlHandled("https://www.example.com")
        assertUrlHandled("https://www.example.com/with/path")
        assertUrlHandled("https://www.example.com?utm_campaign=Newsletter%202021%20Q1")
        assertUrlHandled("https://www.example.com/with/path?and_params=with%20spaces")
    }

    private func assertUrlHandled(_ urlString: String) {
        let handlerCalled = expectation(description: "handler called")
        let listener = UrlEventListener(handler: { _ in
            handlerCalled.fulfill()
        })

        let event = NSAppleEventDescriptor(eventClass: AEEventClass(kInternetEventClass),
                                           eventID: AEEventID(kAEGetURL),
                                           targetDescriptor: nil,
                                           returnID: 0,
                                           transactionID: 0)
        event.setParam(.init(string: urlString), forKeyword: keyDirectObject)
        let reply = NSAppleEventDescriptor()

        listener.handleUrlEvent(event: event, reply: reply)

        waitForExpectations(timeout: 1.0, handler: nil)
    }

}
