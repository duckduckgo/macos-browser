//
//  URLEventHandlerTests.swift
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

final class URLEventHandlerTests: XCTestCase {

    func testWhenInternetEventSentThenItIsHandled() {
        assertUrlHandled("https://www.example.com")
        assertUrlHandled("https://www.example.com/with/path")
        assertUrlHandled("https://www.example.com?utm_campaign=Newsletter%202021%20Q1")
        assertUrlHandled("https://www.example.com/with/path?and_params=with%20spaces")
        assertUrlHandled("http://example.com/?a=http%3A%2F%2Fexample.com%2F%3Fa%3Dbc")
    }

    private func assertUrlHandled(_ urlString: String) {
        let handlerCalled = expectation(description: "handler called")
        let listener = URLEventHandler { url in
            XCTAssertEqual(url.absoluteString, urlString)
            handlerCalled.fulfill()
        }

        let event = NSAppleEventDescriptor(eventClass: AEEventClass(kInternetEventClass),
                                           eventID: AEEventID(kAEGetURL),
                                           targetDescriptor: .init(descriptorType: typeApplicationBundleID,
                                                                   data: Bundle.main.bundleIdentifier!.data(using: .utf8)!),
                                           returnID: 0,
                                           transactionID: 0)
        event.setParam(.init(string: urlString), forKeyword: keyDirectObject)
        listener.applicationDidFinishLaunching()
        listener.handleUrlEvent(event: event, reply: NSAppleEventDescriptor())

        wait(for: [handlerCalled], timeout: 1)
    }

    func testWhenFilePassedOnLaunchThenFileOpenedAfterAppDidFinishLaunching() {
        let filepath = FileManager.default.temporaryDirectory.appendingPathComponent("testres.html").path
        FileManager.default.createFile(atPath: filepath, contents: nil, attributes: nil)
        var handlerCalled: XCTestExpectation!
        let listener = URLEventHandler { url in
            XCTAssertEqual(url.path, filepath)
            handlerCalled.fulfill()
        }

        listener.handleFiles([filepath])

        handlerCalled = expectation(description: "handler called")
        listener.applicationDidFinishLaunching()

        withExtendedLifetime(listener) {
            waitForExpectations(timeout: 1.0, handler: nil)
        }
    }

    func testWhenURLPassedOnLaunchThenURLOpenedAfterAppDidFinishLaunching() {
        let url1 = URL(string: "https://duckduckgo.com")!
        let url2 = URL(string: "data://somedata")!
        var handlerCalled: XCTestExpectation!
        let listener = URLEventHandler { url in
            XCTAssertEqual(url.absoluteString, url1.absoluteString)
            handlerCalled.fulfill()
        }

        listener.handleFiles([url1.absoluteString, url2.absoluteString])

        handlerCalled = expectation(description: "handler called")
        listener.applicationDidFinishLaunching()

        withExtendedLifetime(listener) {
            waitForExpectations(timeout: 1.0, handler: nil)
        }
    }

    func testWhenFileOpenedAfterAppDidFinishLaunchingThenItIsOpened() {
        let url = URL(string: "https://duckduckgo.com")!
        let handlerCalled = expectation(description: "handler called")
        let listener = URLEventHandler { url in
            XCTAssertEqual(url.absoluteString, url.absoluteString)
            handlerCalled.fulfill()
        }
        listener.applicationDidFinishLaunching()

        listener.handleFiles([url.absoluteString])
        withExtendedLifetime(listener) {
            waitForExpectations(timeout: 1.0, handler: nil)
        }
    }

}
