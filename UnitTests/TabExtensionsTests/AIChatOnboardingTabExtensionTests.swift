//
//  AIChatOnboardingTabExtensionTests.swift
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

class AIChatOnboardingTabExtensionTests: XCTestCase {
    var mockWebViewPublisher: PassthroughSubject<WKWebView, Never>!
    var notificationCenter: NotificationCenter!
    var remoteSettings: MockRemoteAISettings!
    var onboardingTabExtension: AIChatOnboardingTabExtension!
    var webView: WKWebView!

    var validURL: URL {
        URL(string: "https://duckduckgo.com/?\(remoteSettings.aiChatURLIdentifiableQuery)=\(remoteSettings.aiChatURLIdentifiableQueryValue)")!
    }

    var invalidURL: URL {
        URL(string: "https://duckduckgo.com/?wrong=value")!
    }

    override func setUp() {
        super.setUp()
        mockWebViewPublisher = PassthroughSubject<WKWebView, Never>()
        notificationCenter = NotificationCenter()
        remoteSettings = MockRemoteAISettings()
        webView = WKWebView()

        onboardingTabExtension = AIChatOnboardingTabExtension(
            webViewPublisher: mockWebViewPublisher.eraseToAnyPublisher(),
            notificationCenter: notificationCenter,
            remoteSettings: remoteSettings
        )
    }

    override func tearDown() {
        onboardingTabExtension = nil
        notificationCenter = nil
        remoteSettings = nil
        mockWebViewPublisher = nil
        webView = nil
        super.tearDown()
    }

    // MARK: - Tests

    @MainActor
    func testNotificationPostedWhenCookieIsPresent() {
        let expectation = self.expectation(description: "Notification posted")
        notificationCenter.addObserver(forName: .AIChatOpenedForReturningUser, object: nil, queue: .main) { _ in
            expectation.fulfill()
        }

        mockWebViewPublisher.send(webView)

        webView.loadHTMLString("<html></html>", baseURL: validURL)

        let cookie = HTTPCookie(properties: [
            .domain: remoteSettings.onboardingCookieDomain,
            .path: "/",
            .name: remoteSettings.onboardingCookieName,
            .value: "testValue",
            .expires: NSDate(timeIntervalSinceNow: 3600)
        ])!

        webView.configuration.websiteDataStore.httpCookieStore.setCookie(cookie) {
            let navigation = Navigation(identity: NavigationIdentity(nil), responders: ResponderChain(), state: .started, isCurrent: true)
            self.onboardingTabExtension.navigationDidFinish(navigation)
        }

        waitForExpectations(timeout: 1.0, handler: nil)
    }

    @MainActor
    func testNoNotificationPostedWhenCookieIsAbsent() {
        let expectation = self.expectation(description: "Notification not posted")
        expectation.isInverted = true

        notificationCenter.addObserver(forName: .AIChatOpenedForReturningUser, object: nil, queue: .main) { _ in
            expectation.fulfill()
        }

        let webView = WKWebView()
        mockWebViewPublisher.send(webView)

        webView.loadHTMLString("<html></html>", baseURL: validURL)

        let navigation = Navigation(identity: NavigationIdentity(nil), responders: ResponderChain(), state: .started, isCurrent: true)

        self.onboardingTabExtension.navigationDidFinish(navigation)

        waitForExpectations(timeout: 1.0, handler: nil)
    }

    @MainActor
    func testNotificationPostedWhenCookieIsPresent_ForInvalidURL_ThenNotificationIsNotPosted() {
        let expectation = self.expectation(description: "Notification posted for invalid URL")
        expectation.isInverted = true

        notificationCenter.addObserver(forName: .AIChatOpenedForReturningUser, object: nil, queue: .main) { _ in
            expectation.fulfill()
        }

        let invalidWebView = WKWebView()
        mockWebViewPublisher.send(invalidWebView)

        invalidWebView.loadHTMLString("<html></html>", baseURL: invalidURL)

        let cookie = HTTPCookie(properties: [
            .domain: remoteSettings.onboardingCookieDomain,
            .path: "/",
            .name: remoteSettings.onboardingCookieName,
            .value: "testValue",
            .expires: NSDate(timeIntervalSinceNow: 3600)
        ])!

        invalidWebView.configuration.websiteDataStore.httpCookieStore.setCookie(cookie) {
            let navigation = Navigation(identity: NavigationIdentity(nil), responders: ResponderChain(), state: .started, isCurrent: true)
            self.onboardingTabExtension.navigationDidFinish(navigation)
        }

        waitForExpectations(timeout: 1.0, handler: nil)
    }

    @MainActor
    func testNoNotificationPostedWhenCookieIsAbsent_ForInvalidURL_ThenNotificationIsNotPosted() {
        let expectation = self.expectation(description: "Notification not posted for invalid URL")
        expectation.isInverted = true

        notificationCenter.addObserver(forName: .AIChatOpenedForReturningUser, object: nil, queue: .main) { _ in
            expectation.fulfill()
        }

        let invalidWebView = WKWebView()
        mockWebViewPublisher.send(invalidWebView)

        invalidWebView.loadHTMLString("<html></html>", baseURL: invalidURL)

        let navigation = Navigation(identity: NavigationIdentity(nil), responders: ResponderChain(), state: .started, isCurrent: true)

        self.onboardingTabExtension.navigationDidFinish(navigation)

        waitForExpectations(timeout: 1.0, handler: nil)
    }
}
