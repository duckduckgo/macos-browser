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

import XCTest
@testable import DuckDuckGo_Privacy_Browser
import Common
import BrowserServicesKit
import Combine
import PhishingDetection

final class DuckSchemeHandlerTests: XCTestCase {

    func testWebViewFromOnboardingHandlerReturnsResponseAndData() throws {
        // Given
        let onboardingURL = URL(string: "duck://onboarding?platform=integration")!
        let handler = DuckURLSchemeHandler()
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

    @MainActor
    func testWebViewFromDuckPlayerHandlerReturnsResponseAndData() throws {
        // Given
        let duckPlayerURL = URL(string: "duck://player")!
        let handler = DuckURLSchemeHandler()
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
        let handler = DuckURLSchemeHandler()
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
        let urlString = "https://privacy-test-pages.site/security/badware/phishing.html"
        let phishingUrl = URL(string: urlString)!
        let encodedURL = URLTokenValidator.base64URLEncode(data: urlString.data(using: .utf8)!)
        let token = URLTokenValidator.shared.generateToken(for: phishingUrl)
        let errorURLString = "duck://error?reason=phishing&url=\(encodedURL)&token=\(token)"
        let errorURL = URL(string: errorURLString)!
        let handler = DuckURLSchemeHandler()
        let webView = WKWebView()
        let schemeTask = MockSchemeTask(request: URLRequest(url: errorURL))

        // When
        handler.webView(webView, start: schemeTask)

        // Then
        let error = PhishingDetectionError.detected
        let expectedError = NSError(domain: PhishingDetectionError.errorDomain, code: error.errorCode, userInfo: [
            NSURLErrorFailingURLErrorKey: phishingUrl,
            NSLocalizedDescriptionKey: error.errorUserInfo[NSLocalizedDescriptionKey] ?? "Phishing detected"
        ])
        XCTAssertEqual(schemeTask.error! as NSError, expectedError)
    }

    @MainActor
    func testErrorPageSchemeHandlerSetsError_WhenTokenInvalid() {
        // Given
        let urlString = "https://privacy-test-pages.site/security/badware/phishing.html"
        let encodedURL = URLTokenValidator.base64URLEncode(data: urlString.data(using: .utf8)!)
        let token = "ababababababababababab"
        let errorURLString = "duck://error?reason=phishing&url=\(encodedURL)&token=\(token)"
        let errorURL = URL(string: errorURLString)!
        let handler = DuckURLSchemeHandler()
        let webView = WKWebView()
        let schemeTask = MockSchemeTask(request: URLRequest(url: errorURL))

        // When
        handler.webView(webView, start: schemeTask)

        // Then
        let error = WKError.unknown
        let expectedError = NSError(domain: "Unexpected Error", code: error.rawValue, userInfo: [
            NSURLErrorFailingURLErrorKey: "about:blank",
            NSLocalizedDescriptionKey: "Unexpected Error"
        ])
        XCTAssertEqual(schemeTask.error! as NSError, expectedError)
    }

    @MainActor
    func testErrorPageSchemeHandlerSetsError_WhenURLContainsParams() {
        // Given
        let urlString = "https://privacy-test-pages.site/?token=foobar&url=http://example.com/injected"
        let phishingUrl = URL(string: urlString)!
        let encodedURL = URLTokenValidator.base64URLEncode(data: urlString.data(using: .utf8)!)
        let token = URLTokenValidator.shared.generateToken(for: phishingUrl)
        let errorURLString = "duck://error?reason=phishing&url=\(encodedURL)&token=\(token)"
        let errorURL = URL(string: errorURLString)!
        let handler = DuckURLSchemeHandler()
        let webView = WKWebView()
        let schemeTask = MockSchemeTask(request: URLRequest(url: errorURL))

        // When
        handler.webView(webView, start: schemeTask)

        // Then
        let error = PhishingDetectionError.detected
        let expectedError = NSError(domain: PhishingDetectionError.errorDomain, code: error.errorCode, userInfo: [
            NSURLErrorFailingURLErrorKey: phishingUrl,
            NSLocalizedDescriptionKey: error.errorUserInfo[NSLocalizedDescriptionKey] ?? "Phishing detected"
        ])
        XCTAssertEqual(schemeTask.error! as NSError, expectedError)
    }

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
