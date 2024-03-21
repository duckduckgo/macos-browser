//
//  ErrorPageTabExtenstionTest.swift
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

import BrowserServicesKit
import Combine
import Navigation
import WebKit
import XCTest

@testable import DuckDuckGo_Privacy_Browser

final class ErrorPageTabExtenstionTest: XCTestCase {

    var mockWebViewPublisher: PassthroughSubject<WKWebView, Never>!
    var errorPageExtention: ErrorPageTabExtension!
    let errorURLString = "com.example.error"

    override func setUpWithError() throws {
        mockWebViewPublisher = PassthroughSubject<WKWebView, Never>()
        errorPageExtention = ErrorPageTabExtension(webViewPublisher: mockWebViewPublisher)
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testWhenWebViewPublisherPublishWebViewThenErrorPageExtensionHasCorrectWebView() throws {
        // GIVEN
        let aWebView = WKWebView()

        // WHEN
        mockWebViewPublisher.send(aWebView)

        // THEN
        XCTAssertTrue(errorPageExtention.webView === aWebView)
    }

    @MainActor func testWhenCertificateExpired_ThenExpectedErrorPageIsShown() {
        // GIVEN
        let mockWebView = MockWKWebView(url: URL(string: errorURLString)!)
        errorPageExtention.webView = mockWebView
        let error = WKError(_nsError: NSError(domain: "com.example.error", code: NSURLErrorServerCertificateUntrusted, userInfo: ["_kCFStreamErrorCodeKey": -9814, "NSErrorFailingURLKey": URL(string: errorURLString)!]))
        let navigation = Navigation(identity: .init(nil), responders: .init(), state: .started, redirectHistory: [], isCurrent: true, isCommitted: true)

        // WHEN
        errorPageExtention.navigation(navigation, didFailWith: error)

        // THEN
        XCTAssertTrue(mockWebView.capturedHTML.contains(ErrorPageTabExtension.SSLErrorType.expired.message(for: errorURLString)))
    }

    @MainActor func testWhenCertificateSelfSigned_ThenExpectedErrorPageIsShown() {
        // GIVEN
        let mockWebView = MockWKWebView(url: URL(string: errorURLString)!)
        errorPageExtention.webView = mockWebView
        let error = WKError(_nsError: NSError(domain: "com.example.error", code: NSURLErrorServerCertificateUntrusted, userInfo: ["_kCFStreamErrorCodeKey": -9807, "NSErrorFailingURLKey": URL(string: errorURLString)!]))
        let navigation = Navigation(identity: .init(nil), responders: .init(), state: .started, redirectHistory: [], isCurrent: true, isCommitted: true)

        // WHEN
        errorPageExtention.navigation(navigation, didFailWith: error)

        // THEN
        XCTAssertTrue(mockWebView.capturedHTML.contains(ErrorPageTabExtension.SSLErrorType.selfSigned.message(for: errorURLString)))
    }

    @MainActor func testWhenCertificateWrongHost_ThenExpectedErrorPageIsShown() {
        // GIVEN
        let mockWebView = MockWKWebView(url: URL(string: errorURLString)!)
        errorPageExtention.webView = mockWebView
        let error = WKError(_nsError: NSError(domain: "com.example.error", code: NSURLErrorServerCertificateUntrusted, userInfo: ["_kCFStreamErrorCodeKey": -9843, "NSErrorFailingURLKey": URL(string: errorURLString)!]))
        let navigation = Navigation(identity: .init(nil), responders: .init(), state: .started, redirectHistory: [], isCurrent: true, isCommitted: true)

        // WHEN
        errorPageExtention.navigation(navigation, didFailWith: error)

        // THEN
        XCTAssertTrue(mockWebView.capturedHTML.contains(ErrorPageTabExtension.SSLErrorType.wrongHost.message(for: errorURLString)))
    }

    @MainActor func testWhenGenericError_ThenExpectedErrorPageIsShown() {
        // GIVEN
        let mockWebView = MockWKWebView(url: URL(string: errorURLString)!)
        errorPageExtention.webView = mockWebView
        let errorDescription = "some error"
        let error = WKError(_nsError: NSError(domain: "com.example.error", code: NSURLErrorUnknown, userInfo: ["_kCFStreamErrorCodeKey": -9843, "NSErrorFailingURLKey": URL(string: errorURLString)!, NSLocalizedDescriptionKey: errorDescription]))
        let navigation = Navigation(identity: .init(nil), responders: .init(), state: .started, redirectHistory: [], isCurrent: true, isCommitted: true)

        // WHEN
        errorPageExtention.navigation(navigation, didFailWith: error)

        // THEN
        XCTAssertTrue(mockWebView.capturedHTML.contains("DuckDuckGo can’t load this page."))
        XCTAssertTrue(mockWebView.capturedHTML.contains(errorDescription))
    }
}

class MockWKWebView: NSObject, ErrorPageTabExtensionDelegate {
    var url: URL?
    var capturedHTML: String = ""

    init(url: URL) {
        self.url = url
    }

    func loadAlternateHTML(_ html: String, baseURL: URL, forUnreachableURL failingURL: URL) {
        capturedHTML = html
    }

    func setDocumentHtml(_ html: String) {
        capturedHTML = html
    }
}
