//
//  WebViewExtensionTests.swift
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

final class WebViewExtensionTests: XCTestCase {

    func testWebViewEvaluateSynchronously() {
        let webView = WKWebView(frame: CGRect())

        let result = try? webView.evaluateSynchronously("1 + 1") as? Int
        XCTAssertEqual(result, 2)
    }

    func testWhenEvaluateSynchronouslySleepsThenEvaluationWaits() {
        let webView = WKWebView(frame: CGRect())

        let script = """
            function sleep(millis) {
                var date = new Date();
                var curDate = null;
                do { curDate = new Date(); }
                while(curDate-date < millis);
            }
            sleep(100);
            1;
        """

        let result = try? webView.evaluateSynchronously(script) as? Int
        XCTAssertEqual(result, 1)
    }

    func testWhenEvaluateSynchronouslyTimeoutsThenErrorIsThrown() {
        let webView = WKWebView(frame: CGRect())

        let script = """
            function sleep(millis) {
                var date = new Date();
                var curDate = null;
                do { curDate = new Date(); }
                while(curDate-date < millis);
            }
            sleep(1000);
            1;
        """

        XCTAssertThrowsError(try webView.evaluateSynchronously(script, timeout: 0.1), "evaluateSynchronously should timeout") { error in
            XCTAssertTrue(error is WKWebView.EvaluateTimeout)
        }
    }

    func testWhenWebViewDisplaysPageThenContentTypeIsHtml() {
        let webView = WKWebView(frame: CGRect())

        let delegate = TestNavigationDelegate(e: expectation(description: "loaded"))
        webView.navigationDelegate = delegate

        webView.loadHTMLString("<html></html>", baseURL: nil)

        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(webView.contentType, .html)
    }

    func testWhenWebViewDisplaysImageThenContentTypeIsJpeg() {
        let webView = WKWebView(frame: CGRect())

        let delegate = TestNavigationDelegate(e: expectation(description: "loaded"))
        webView.navigationDelegate = delegate

        let url = Bundle(for: Self.self).url(forResource: "DuckDuckGo-Symbol", withExtension: "jpg")!
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())

        withExtendedLifetime(delegate) {
            waitForExpectations(timeout: 1.0)
        }

        XCTAssertEqual(webView.contentType, .jpeg)
    }

}

private class TestNavigationDelegate: NSObject, WKNavigationDelegate {
    let e: XCTestExpectation

    init(e: XCTestExpectation) {
        self.e = e
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        e.fulfill()
    }
}
