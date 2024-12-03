//
//  DuckSchemeHandlerTests.swift
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
import Common
import MaliciousSiteProtection
import XCTest

@testable import DuckDuckGo_Privacy_Browser

final class DuckSchemeHandlerTests: XCTestCase {

    var featureFlagger: MockFeatureFlagger!
    var handler: DuckURLSchemeHandler!

    override func setUp() {
        super.setUp()
        featureFlagger = MockFeatureFlagger()
        featureFlagger.isFeatureOn = false

        handler = DuckURLSchemeHandler(featureFlagger: featureFlagger)
    }

    func testWebViewFromOnboardingHandlerReturnsResponseAndData() throws {
        // Given
        let onboardingURL = URL(string: "duck://onboarding")!
        let webView = WKWebView()
        let schemeTask = MockSchemeTask(request: URLRequest(url: onboardingURL))

        // When
        handler.webView(webView, start: schemeTask)

        // Then
        XCTAssertEqual(schemeTask.response?.url, onboardingURL)
        XCTAssertEqual(schemeTask.response?.mimeType, "text/html")
        XCTAssertNotNil(schemeTask.data)
        XCTAssertTrue(schemeTask.data?.utf8String()?.contains("<title>Welcome</title>") ?? false)
        XCTAssertTrue(schemeTask.didFinishCalled)
        XCTAssertNil(schemeTask.error)
    }

    func testWebViewFromReleaseNoteHandlerReturnsResponseAndData() throws {
        // Given
        let releaseNotesURL = URL(string: "duck://release-notes")!
        let webView = WKWebView()
        let schemeTask = MockSchemeTask(request: URLRequest(url: releaseNotesURL))

        // When
        handler.webView(webView, start: schemeTask)

        // Then
        XCTAssertEqual(schemeTask.response?.url, releaseNotesURL)
        XCTAssertEqual(schemeTask.response?.mimeType, "text/html")
        XCTAssertNotNil(schemeTask.data)
        XCTAssertTrue(schemeTask.data?.utf8String()?.contains("<title>Browser Release Notes</title>") ?? false)
        XCTAssertTrue(schemeTask.didFinishCalled)
        XCTAssertNil(schemeTask.error)
    }

    @MainActor
    func testWebViewFromDuckPlayerHandlerReturnsResponseAndData() throws {
        // Given
        let duckPlayerURL = URL(string: "duck://player")!
        let webView = WKWebView()
        let schemeTask = MockSchemeTask(request: URLRequest(url: duckPlayerURL))

        // When
        handler.webView(webView, start: schemeTask)

        // Then
        XCTAssertNil(schemeTask.response)
        XCTAssertNil(schemeTask.data)
        XCTAssertFalse(schemeTask.didFinishCalled)
        XCTAssertNil(schemeTask.error)
    }

    func testWebViewFromNativeUIHandlerReturnsResponseAndData() throws {
        // Given
        let nativeURL = URL(string: "duck://newtab")!
        let webView = WKWebView()
        let schemeTask = MockSchemeTask(request: URLRequest(url: nativeURL))

        // When
        handler.webView(webView, start: schemeTask)

        // Then
        XCTAssertEqual(schemeTask.response?.url, nativeURL)
        XCTAssertEqual(schemeTask.response?.mimeType, "text/html")
        XCTAssertNotNil(schemeTask.data)
        XCTAssertEqual(schemeTask.data, DuckURLSchemeHandler.emptyHtml.utf8data)
        XCTAssertTrue(schemeTask.didFinishCalled)
        XCTAssertNil(schemeTask.error)
    }

    @MainActor
    func testSetOnboardingSchemeHandler_WhenNoneExists() {
        // Given
        let configuration = WKWebViewConfiguration()
        XCTAssertNil(configuration.urlSchemeHandler(forURLScheme: "duck"))

        // When
        configuration.applyStandardConfiguration(contentBlocking: MockContentBlocking(), burnerMode: .regular)

        // Then
        XCTAssertNotNil(configuration.urlSchemeHandler(forURLScheme: "duck"))
        XCTAssertTrue(configuration.urlSchemeHandler(forURLScheme: "duck") is DuckURLSchemeHandler)
    }

    @MainActor
    func testErrorPageSchemeHandlerSetsError() {
        // Given
        let phishingUrl = URL(string: "https://privacy-test-pages.site/security/badware/phishing.html")!
        let encodedURL = URLTokenValidator.base64URLEncode(phishingUrl)
        let token = URLTokenValidator.shared.generateToken(for: phishingUrl)
        let errorURLString = "duck://error?reason=phishing&url=\(encodedURL)&token=\(token)"
        let errorURL = URL(string: errorURLString)!
        let webView = WKWebView()
        let schemeTask = MockSchemeTask(request: URLRequest(url: errorURL))

        // When
        handler.webView(webView, start: schemeTask)

        // Then
        let expectedError = MaliciousSiteError(code: .phishing, failingUrl: phishingUrl)
        XCTAssertEqual(schemeTask.error as NSError?, expectedError as NSError)
    }

    @MainActor
    func testErrorPageSchemeHandlerSetsError_WhenTokenInvalid() {
        // Given
        let url = URL(string: "https://privacy-test-pages.site/security/badware/phishing.html")!
        let encodedURL = URLTokenValidator.base64URLEncode(url)
        let token = "ababababababababababab"
        let errorURLString = "duck://error?reason=phishing&url=\(encodedURL)&token=\(token)"
        let errorURL = URL(string: errorURLString)!
        let webView = WKWebView()
        let schemeTask = MockSchemeTask(request: URLRequest(url: errorURL))

        // When
        handler.webView(webView, start: schemeTask)

        // Then
        XCTAssertNotNil(schemeTask.error)
        XCTAssertEqual((schemeTask.error! as? URLError)?.code, .badURL)
    }

    @MainActor

    class MockWebView: WKWebView {
        var lastURLRequest: URLRequest?
        var lastLoadedHTML: String?

        override func loadSimulatedRequest(_ request: URLRequest, responseHTML: String) -> WKNavigation {
            self.lastURLRequest = request
            self.lastLoadedHTML = responseHTML

            return WKNavigation()
        }
    }
}
