//
//  WKWebViewPrivateMethodsAvailabilityTests.swift
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

import XCTest
import WebKit
@testable import DuckDuckGo_Privacy_Browser

final class WKWebViewPrivateMethodsAvailabilityTests: XCTestCase {

    func testWebViewRespondsTo_sessionStateData() {
        let webView = WebView.init(frame: CGRect(), configuration: .init())

        XCTAssertNoThrow(try XCTAssertNotNil(webView.sessionStateData()))
    }

    func testWebViewRespondsTo_restoreFromSessionStateData() {
        let webView = WebView(frame: CGRect(), configuration: .init())
        XCTAssertNoThrow(try webView.restoreSessionState(from: Data()))
    }

    func testWebViewRespondsTo_printOperationWithPrintInfo() {
        XCTAssertTrue(WKWebView.instancesRespond(to: #selector(WKWebView._printOperation(with:))))
        XCTAssertTrue(WKWebView.instancesRespond(to: #selector(WKWebView._printOperation(with:forFrame:))))
    }

    func testWebViewRespondsTo_fullScreenPlaceholderView() {
        XCTAssertTrue(WKWebView.instancesRespond(to: #selector(WKWebView._fullScreenPlaceholderView)))
    }

}
