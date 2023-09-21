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
import UniformTypeIdentifiers
import WebKit
@testable import DuckDuckGo_Privacy_Browser

final class WebViewExtensionTests: XCTestCase {

    func testWhenWebViewDisplaysPageThenContentTypeIsHtml() {
        let webView = WKWebView(frame: CGRect())

        let delegate = TestNavigationDelegate(e: expectation(description: "loaded"))
        webView.navigationDelegate = delegate

        webView.loadHTMLString("<html></html>", baseURL: nil)

        waitForExpectations(timeout: 5.0)

        let e = expectation(description: "mimeType callback")
        Task {
            let mimeType = await webView.mimeType
            XCTAssertEqual(mimeType, UTType.html.preferredMIMEType!)
            e.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    func testWhenWebViewDisplaysImageThenContentTypeIsJpeg() {
        let webView = WKWebView(frame: CGRect())

        let delegate = TestNavigationDelegate(e: expectation(description: "loaded"))
        webView.navigationDelegate = delegate

        let url = Bundle(for: Self.self).url(forResource: "DuckDuckGo-Symbol", withExtension: "jpg")!
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())

        withExtendedLifetime(delegate) {
            waitForExpectations(timeout: 5.0)
        }

        let e = expectation(description: "mimeType callback")
        Task {
            let mimeType = await webView.mimeType
            XCTAssertEqual(mimeType, UTType.jpeg.preferredMIMEType!)
            e.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

}
