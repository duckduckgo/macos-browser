//
//  DuckPlayerOnboardingLocationValidatorTests.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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
@testable import DuckDuckGo_Privacy_Browser
import Navigation
class DuckPlayerOnboardingLocationValidatorTests: XCTestCase {

    var validator: DuckPlayerOnboardingLocationValidator!

    override func setUp() {
        super.setUp()
        validator = DuckPlayerOnboardingLocationValidator()
    }

    @MainActor
    func testIsValidLocation_RootURL_ReturnsTrue() async {
        let webView = MockWebView()
        webView.mockURL = URL(string: "https://www.youtube.com/")
        let result = await validator.isValidLocation(webView)
        XCTAssertTrue(result)
    }

    @MainActor
    func testIsValidLocation_NonRootURL_ReturnsFalse() async {
        let webView = MockWebView()
        webView.mockURL = URL(string: "https://www.youtube.com/duckduckgo")
        let result = await validator.isValidLocation(webView)
        XCTAssertFalse(result)
    }

    @MainActor
    func testIsValidLocation_NonYoutubeURL_ReturnsFalse() async {
        let webView = MockWebView()
        webView.mockURL = URL(string: "https://www.duckduckgo.com/")
        let result = await validator.isValidLocation(webView)
        XCTAssertFalse(result)
    }

    @MainActor
    func testIsValidLocation_NoURL_ReturnsFalse() async {
        let webView = MockWebView()
        webView.mockURL = nil
        let result = await validator.isValidLocation(webView)
        XCTAssertFalse(result)
    }

    @MainActor
    func testIsCurrentWebViewInAYoutubeChannel_ChannelURL_ReturnsTrue() async {
        let webView = MockWebView()
        webView.mockURL = URL(string: "https://www.youtube.com/duckduckgo")!
        webView.evaluateJavaScriptResult = true
        let result = await validator.isValidLocation(webView)
        XCTAssertTrue(result)
    }

    @MainActor
    func testIsCurrentWebViewInAYoutubeChannel_NonChannelURL_ReturnsFalse() async {
        let webView = MockWebView()
        webView.mockURL = URL(string: "https://www.youtube.com/settings")!
        webView.evaluateJavaScriptResult = false
        let result = await validator.isValidLocation(webView)
        XCTAssertFalse(result)
    }

}
private final class MockWebView: WKWebView {
    var mockURL: URL?
    var evaluateJavaScriptResult: Any?

    override var url: URL? {
        return mockURL
    }

    override func evaluateJavaScript(_ javaScriptString: String, completionHandler: ((Any?, Error?) -> Void)? = nil) {
        completionHandler?(evaluateJavaScriptResult, nil)
    }
}
