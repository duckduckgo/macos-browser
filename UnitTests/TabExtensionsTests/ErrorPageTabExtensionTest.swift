//
//  ErrorPageTabExtensionTest.swift
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
import Navigation
import SpecialErrorPages
import WebKit
import XCTest

@testable import DuckDuckGo_Privacy_Browser

extension WKError {
    static func serverCertificateUntrustedError(sslErrorCode: Int32, url: String) -> WKError {
        WKError(_nsError: NSError(domain: NSURLErrorDomain, code: NSURLErrorServerCertificateUntrusted, userInfo: [
            SSLErrorCodeKey: sslErrorCode,
            NSURLErrorFailingURLErrorKey: URL(string: url)!,
        ]))
    }
}

final class ErrorPageTabExtensionTest: XCTestCase {
    var mockWebViewPublisher: PassthroughSubject<MockWKWebView, Never>!
    var scriptPublisher: PassthroughSubject<MockSpecialErrorPageScriptProvider, Never>!
    var errorPageExtention: SpecialErrorPageTabExtension!
    var credentialCreator: MockCredentialCreator!
    var detector: MockMaliciousSiteDetector!
    let errorURLString = "com.example.error"
    let phishingURLString = "https://privacy-test-pages.site/security/phishing.html"
    private var onCloseTab: (() -> Void) = {
        XCTFail("Unexpected call to closeTab")
    }

    override func setUpWithError() throws {
        mockWebViewPublisher = PassthroughSubject<MockWKWebView, Never>()
        scriptPublisher = PassthroughSubject<MockSpecialErrorPageScriptProvider, Never>()
        let featureFlagger = MockFeatureFlagger()
        credentialCreator = MockCredentialCreator()
        detector = MockMaliciousSiteDetector { _ in .phishing }
        errorPageExtention = SpecialErrorPageTabExtension(webViewPublisher: mockWebViewPublisher, scriptsPublisher: scriptPublisher, closeTab: self.closeTab, urlCredentialCreator: credentialCreator, featureFlagger: featureFlagger, maliciousSiteDetector: detector)
    }

    override func tearDownWithError() throws {
        mockWebViewPublisher = nil
        scriptPublisher = nil
        errorPageExtention = nil
        credentialCreator = nil
    }

    private func closeTab() {
        onCloseTab()
    }

    @MainActor func testWhenCertificateExpired_ThenTabExtenstionErrorIsExpectedError() {
        // GIVEN
        let mockWebView = MockWKWebView(url: URL(string: errorURLString)!)
        mockWebViewPublisher.send(mockWebView)
        let error = WKError.serverCertificateUntrustedError(sslErrorCode: -9814, url: errorURLString)
        let navigation = Navigation(identity: .init(nil), responders: .init(), state: .started, redirectHistory: [], isCurrent: true, isCommitted: true)
        let eTldPlus1 = TLD().eTLDplus1(errorURLString) ?? errorURLString

        // WHEN
        errorPageExtention.navigation(navigation, didFailWith: error)

        // THEN
        XCTAssertEqual(errorPageExtention.errorData, SpecialErrorData.ssl(type: .expired, domain: eTldPlus1, eTldPlus1: nil))
    }

    @MainActor func testWhenCertificateSelfSigned_ThenExpectedErrorPageIsShown() {
        // GIVEN
        let mockWebView = MockWKWebView(url: URL(string: errorURLString)!)
        mockWebViewPublisher.send(mockWebView)
        let error = WKError.serverCertificateUntrustedError(sslErrorCode: -9807, url: errorURLString)
        let navigation = Navigation(identity: .init(nil), responders: .init(), state: .started, redirectHistory: [], isCurrent: true, isCommitted: true)
        let eTldPlus1 = TLD().eTLDplus1(errorURLString) ?? errorURLString

        // WHEN
        errorPageExtention.navigation(navigation, didFailWith: error)

        // THEN
        XCTAssertEqual(errorPageExtention.errorData, SpecialErrorData.ssl(type: .selfSigned, domain: eTldPlus1, eTldPlus1: nil))
    }

    @MainActor func testWhenCertificateWrongHost_ThenExpectedErrorPageIsShown() {
        // GIVEN
        let mockWebView = MockWKWebView(url: URL(string: errorURLString)!)
        mockWebViewPublisher.send(mockWebView)
        let error = WKError.serverCertificateUntrustedError(sslErrorCode: -9843, url: errorURLString)
        let navigation = Navigation(identity: .init(nil), responders: .init(), state: .started, redirectHistory: [], isCurrent: true, isCommitted: true)
        let eTldPlus1 = TLD().eTLDplus1(errorURLString) ?? errorURLString

        // WHEN
        errorPageExtention.navigation(navigation, didFailWith: error)

        // THEN
        XCTAssertEqual(errorPageExtention.errorData, SpecialErrorData.ssl(type: .wrongHost, domain: eTldPlus1, eTldPlus1: nil))
    }

    @MainActor func test_WhenUserScriptsPublisherPublishSSLErrorPageScript_ThenErrorPageExtensionIsSetAsUserScriptDelegate() {
        // GIVEN
        let userScript = SpecialErrorPageUserScript(localeStrings: SpecialErrorPageUserScript.localeStrings(),
                                                    languageCode: Locale.current.languageCode ?? "en")
        let mockScriptProvider = MockSpecialErrorPageScriptProvider(script: userScript)

        // WHEN
        scriptPublisher.send(mockScriptProvider)

        // THEN
        XCTAssertNotNil(userScript.delegate)
    }

    @MainActor func testWhenNavigationEnded_IfNoFailure_SSLUserScriptIsNotEnabled() {
        // GIVEN
        let userScript = SpecialErrorPageUserScript(localeStrings: SpecialErrorPageUserScript.localeStrings(),
                                                    languageCode: Locale.current.languageCode ?? "en")
        let mockScriptProvider = MockSpecialErrorPageScriptProvider(script: userScript)
        let mockWebView = MockWKWebView(url: URL(string: errorURLString)!)
        let action = NavigationAction(request: URLRequest(url: URL(string: "com.example.error")!), navigationType: .custom(.userEnteredUrl), currentHistoryItemIdentity: nil, redirectHistory: nil, isUserInitiated: true, sourceFrame: FrameInfo(frame: WKFrameInfo()), targetFrame: nil, shouldDownload: false, mainFrameNavigation: nil)
        let navigation = Navigation(identity: .init(nil), responders: .init(), state: .started, redirectHistory: [action], isCurrent: true, isCommitted: true)
        mockWebViewPublisher.send(mockWebView)
        scriptPublisher.send(mockScriptProvider)

        // WHEN
        errorPageExtention.navigationDidFinish(navigation)

        // THEN
        XCTAssertFalse(userScript.isEnabled)
        XCTAssertNil(errorPageExtention.errorData)
    }

    @MainActor func testWhenNavigationEnded_IfNonSSLFailure_SSLUserScriptIsNotEnabled() {
        // GIVEN
        let userScript = SpecialErrorPageUserScript(localeStrings: SpecialErrorPageUserScript.localeStrings(),
                                                    languageCode: Locale.current.languageCode ?? "en")
        let mockScriptProvider = MockSpecialErrorPageScriptProvider(script: userScript)
        let mockWebView = MockWKWebView(url: URL(string: errorURLString)!)
        let action = NavigationAction(request: URLRequest(url: URL(string: "com.example.error")!), navigationType: .custom(.userEnteredUrl), currentHistoryItemIdentity: nil, redirectHistory: nil, isUserInitiated: true, sourceFrame: FrameInfo(frame: WKFrameInfo()), targetFrame: nil, shouldDownload: false, mainFrameNavigation: nil)
        let navigation = Navigation(identity: .init(nil), responders: .init(), state: .started, redirectHistory: [action], isCurrent: true, isCommitted: true)
        let errorDescription = "some error"
        let error = WKError(_nsError: NSError(domain: "com.example.error", code: NSURLErrorUnknown, userInfo: [SSLErrorCodeKey: -9843, NSURLErrorFailingURLErrorKey: URL(string: errorURLString)!, NSLocalizedDescriptionKey: errorDescription]))
        mockWebViewPublisher.send(mockWebView)
        scriptPublisher.send(mockScriptProvider)
        errorPageExtention.navigation(navigation, didFailWith: error)

        // WHEN
        let errorNavigationAction = NavigationAction(request: URLRequest(url: URL(string: "com.example.error")!), navigationType: .alternateHtmlLoad, currentHistoryItemIdentity: nil, redirectHistory: nil, isUserInitiated: true, sourceFrame: FrameInfo(frame: WKFrameInfo()), targetFrame: nil, shouldDownload: false, mainFrameNavigation: nil)
        let errorNavigation = Navigation(identity: .init(nil), responders: .init(), state: .started, redirectHistory: [errorNavigationAction], isCurrent: true, isCommitted: true)
        errorPageExtention.navigationDidFinish(errorNavigation)

        // THEN
        XCTAssertFalse(userScript.isEnabled)
        XCTAssertNil(errorPageExtention.errorData)
    }

    @MainActor func testWhenNavigationEnded_IfSSLFailure_AndErrorURLIsTheSameAsNavigationURL_SSLUserScriptIsEnabled() {
        // GIVEN
        let userScript = SpecialErrorPageUserScript(localeStrings: SpecialErrorPageUserScript.localeStrings(),
                                                    languageCode: Locale.current.languageCode ?? "en")
        let mockScriptProvider = MockSpecialErrorPageScriptProvider(script: userScript)
        let mockWebView = MockWKWebView(url: URL(string: errorURLString)!)
        let action = NavigationAction(request: URLRequest(url: URL(string: "com.example.error")!), navigationType: .custom(.userEnteredUrl), currentHistoryItemIdentity: nil, redirectHistory: nil, isUserInitiated: true, sourceFrame: FrameInfo(frame: WKFrameInfo()), targetFrame: nil, shouldDownload: false, mainFrameNavigation: nil)
        let navigation = Navigation(identity: .init(nil), responders: .init(), state: .started, redirectHistory: [action], isCurrent: true, isCommitted: true)
        let error = WKError.serverCertificateUntrustedError(sslErrorCode: -9843, url: errorURLString)
        mockWebViewPublisher.send(mockWebView)
        scriptPublisher.send(mockScriptProvider)
        errorPageExtention.navigation(navigation, didFailWith: error)

        // WHEN
        let errorNavigationAction = NavigationAction(request: URLRequest(url: URL(string: "com.example.error")!), navigationType: .alternateHtmlLoad, currentHistoryItemIdentity: nil, redirectHistory: nil, isUserInitiated: true, sourceFrame: FrameInfo(frame: WKFrameInfo()), targetFrame: nil, shouldDownload: false, mainFrameNavigation: nil)
        let errorNavigation = Navigation(identity: .init(nil), responders: .init(), state: .started, redirectHistory: [errorNavigationAction], isCurrent: true, isCommitted: true)
        errorPageExtention.navigationDidFinish(errorNavigation)

        // THEN
        XCTAssertTrue(userScript.isEnabled)
        XCTAssertNotNil(errorPageExtention.errorData)
    }

    @MainActor
    func testWhenLeaveSiteCalled_AndCanGoBackTrue_ThenWebViewGoesBack() {
        // GIVEN
        let mockWebView = MockWKWebView(url: URL(string: errorURLString)!)
        mockWebViewPublisher.send(mockWebView)
        let error = WKError.serverCertificateUntrustedError(sslErrorCode: -9843, url: errorURLString)
        let navigation = Navigation(identity: .init(nil), responders: .init(), state: .started, redirectHistory: [], isCurrent: true, isCommitted: true)
        errorPageExtention.navigation(navigation, didFailWith: error)

        // WHEN
        mockWebView.canGoBack = true
        errorPageExtention.leaveSiteAction()

        // THEN
        XCTAssertFalse(mockWebView.openNewTabCalled)
        XCTAssertTrue(mockWebView.goBackCalled)
    }

    @MainActor
    func testWhenLeaveSiteCalled_AndCanGoBackFalse_ThenTabIsClosedAndNewTabOpened() async {
        // GIVEN
        let mockWebView = MockWKWebView(url: URL(string: errorURLString)!)
        mockWebViewPublisher.send(mockWebView)
        let error = WKError.serverCertificateUntrustedError(sslErrorCode: -9843, url: errorURLString)
        let navigation = Navigation(identity: .init(nil), responders: .init(), state: .started, redirectHistory: [], isCurrent: true, isCommitted: true)
        errorPageExtention.navigation(navigation, didFailWith: error)

        let eTabClosed = expectation(description: "Tab closed")
        onCloseTab = { eTabClosed.fulfill() }

        // WHEN
        mockWebView.canGoBack = false
        errorPageExtention.leaveSiteAction()

        // THEN
        await fulfillment(of: [eTabClosed], timeout: 1)
        XCTAssertTrue(mockWebView.openNewTabCalled)
    }

    @MainActor
    func testWhenLeaveSiteCalledForPhishingWebsite_ThenTabIsClosedAndNewTabOpened() async {
        // GIVEN
        let mockWebView = MockWKWebView(url: URL(string: phishingURLString)!)
        let mainFrameNavigation = Navigation(identity: NavigationIdentity(nil), responders: ResponderChain(), state: .started, isCurrent: true)
        let urlRequest = URLRequest(url: URL(string: phishingURLString)!)
        let mainFrameTarget = FrameInfo(webView: nil, handle: FrameHandle(rawValue: 1 as UInt64)!, isMainFrame: true, url: URL(string: phishingURLString)!, securityOrigin: .empty)
        let navigationAction = NavigationAction(request: urlRequest, navigationType: .custom(.userEnteredUrl), currentHistoryItemIdentity: nil, redirectHistory: [NavigationAction](), isUserInitiated: true, sourceFrame: FrameInfo(frame: WKFrameInfo()), targetFrame: mainFrameTarget, shouldDownload: false, mainFrameNavigation: mainFrameNavigation)
        var preferences = NavigationPreferences(userAgent: "dummy", contentMode: .desktop, javaScriptEnabled: true)
        mockWebViewPublisher.send(mockWebView)
        _=await errorPageExtention.decidePolicy(for: navigationAction, preferences: &preferences)
        errorPageExtention.navigation(mainFrameNavigation, didFailWith: WKError(_nsError: MaliciousSiteError(code: .phishing, failingUrl: URL(string: phishingURLString)!) as NSError))

        let eTabClosed = expectation(description: "Tab closed")
        onCloseTab = { eTabClosed.fulfill() }

        // WHEN
        errorPageExtention.leaveSiteAction()

        // THEN
        await fulfillment(of: [eTabClosed], timeout: 1)
        XCTAssertTrue(mockWebView.openNewTabCalled)
    }

    @MainActor
    func testWhenLeaveSiteCalledForMalwareWebsite_ThenTabIsClosedAndNewTabOpened() async {
        // GIVEN
        detector.isMalicious = { _ in .malware }
        let mockWebView = MockWKWebView(url: URL(string: phishingURLString)!)
        let mainFrameNavigation = Navigation(identity: NavigationIdentity(nil), responders: ResponderChain(), state: .started, isCurrent: true)
        let urlRequest = URLRequest(url: URL(string: phishingURLString)!)
        let mainFrameTarget = FrameInfo(webView: nil, handle: FrameHandle(rawValue: 1 as UInt64)!, isMainFrame: true, url: URL(string: phishingURLString)!, securityOrigin: .empty)
        let navigationAction = NavigationAction(request: urlRequest, navigationType: .custom(.userEnteredUrl), currentHistoryItemIdentity: nil, redirectHistory: [NavigationAction](), isUserInitiated: true, sourceFrame: FrameInfo(frame: WKFrameInfo()), targetFrame: mainFrameTarget, shouldDownload: false, mainFrameNavigation: mainFrameNavigation)
        var preferences = NavigationPreferences(userAgent: "dummy", contentMode: .desktop, javaScriptEnabled: true)
        mockWebViewPublisher.send(mockWebView)
        _=await errorPageExtention.decidePolicy(for: navigationAction, preferences: &preferences)
        errorPageExtention.navigation(mainFrameNavigation, didFailWith: WKError(_nsError: MaliciousSiteError(code: .malware, failingUrl: URL(string: phishingURLString)!) as NSError))

        let eTabClosed = expectation(description: "Tab closed")
        onCloseTab = { eTabClosed.fulfill() }

        // WHEN
        errorPageExtention.leaveSiteAction()

        // THEN
        await fulfillment(of: [eTabClosed], timeout: 1)
        XCTAssertTrue(mockWebView.openNewTabCalled)
    }

    @MainActor
    func testWhenVisitSiteCalled_ThenWebViewReloads() {
        // GIVEN
        let mockWebView = MockWKWebView(url: URL(string: errorURLString)!)
        mockWebViewPublisher.send(mockWebView)

        // WHEN
        errorPageExtention.visitSiteAction()

        // THEN
        XCTAssertTrue(mockWebView.reloadCalled)
        XCTAssertFalse(mockWebView.openNewTabCalled)
    }

    @MainActor
    func testWhenDidReceiveChallange_IfChallangeForCertificateValidation_AndUserRequestBypass_AndNavigationURLIsTheSameAsWebViewURL_ThenReturnsCredentials() async {
        // GIVEN
        let protectionSpace = URLProtectionSpace(host: "", port: 4, protocol: nil, realm: nil, authenticationMethod: NSURLAuthenticationMethodServerTrust)
        let action = NavigationAction(request: URLRequest(url: URL(string: "com.example.error")!), navigationType: .custom(.userEnteredUrl), currentHistoryItemIdentity: nil, redirectHistory: nil, isUserInitiated: true, sourceFrame: FrameInfo(frame: WKFrameInfo()), targetFrame: nil, shouldDownload: false, mainFrameNavigation: nil)
        let navigation = Navigation(identity: .init(nil), responders: .init(), state: .started, redirectHistory: [action], isCurrent: true, isCommitted: true)
        let mockWebView = MockWKWebView(url: URL(string: errorURLString)!)
        let error = WKError.serverCertificateUntrustedError(sslErrorCode: -9843, url: errorURLString)
        mockWebViewPublisher.send(mockWebView)
        errorPageExtention.navigation(navigation, didFailWith: error)
        errorPageExtention.visitSiteAction()

        // WHEN
        var disposition = await errorPageExtention.didReceive(URLAuthenticationChallenge(protectionSpace: protectionSpace, proposedCredential: nil, previousFailureCount: 0, failureResponse: nil, error: nil, sender: ChallangeSender()), for: navigation)

        // THEN
        if case .credential(let credential) = disposition {
            XCTAssertNotNil(credential)
        } else {
            XCTFail("No credentials found")
        }

        // WHEN
        disposition = await errorPageExtention.didReceive(URLAuthenticationChallenge(protectionSpace: protectionSpace, proposedCredential: nil, previousFailureCount: 0, failureResponse: nil, error: nil, sender: ChallangeSender()), for: navigation)

        // THEN
        XCTAssertNil(disposition)
    }

    @MainActor
    func testWhenDidReceiveChallange_IfChallangeNotForCertificateValidation_AndUserRequestBypass_AndNavigationURLIsTheSameAsWebViewURL_ThenReturnsNoCredentials() async {
        // GIVEN
        let protectionSpace = URLProtectionSpace(host: "", port: 4, protocol: nil, realm: nil, authenticationMethod: NSURLAuthenticationMethodClientCertificate)
        let action = NavigationAction(request: URLRequest(url: URL(string: "com.example.error")!), navigationType: .custom(.userEnteredUrl), currentHistoryItemIdentity: nil, redirectHistory: nil, isUserInitiated: true, sourceFrame: FrameInfo(frame: WKFrameInfo()), targetFrame: nil, shouldDownload: false, mainFrameNavigation: nil)
        let navigation = Navigation(identity: .init(nil), responders: .init(), state: .started, redirectHistory: [action], isCurrent: true, isCommitted: true)
        let mockWebView = MockWKWebView(url: URL(string: errorURLString)!)
        mockWebViewPublisher.send(mockWebView)
        errorPageExtention.visitSiteAction()

        // WHEN
        let disposition = await errorPageExtention.didReceive(URLAuthenticationChallenge(protectionSpace: protectionSpace, proposedCredential: nil, previousFailureCount: 0, failureResponse: nil, error: nil, sender: ChallangeSender()), for: navigation)

        // THEN
        XCTAssertNil(disposition)
    }

    @MainActor
    func testWhenDidReceiveChallange_IfChallangeForCertificateValidation_AndUserDoesNotRequestBypass_AndNavigationURLIsTheSameAsWebViewURL_ThenReturnsNoCredentials() async {
        // GIVEN
        let protectionSpace = URLProtectionSpace(host: "", port: 4, protocol: nil, realm: nil, authenticationMethod: NSURLAuthenticationMethodServerTrust)
        let action = NavigationAction(request: URLRequest(url: URL(string: "com.example.error")!), navigationType: .custom(.userEnteredUrl), currentHistoryItemIdentity: nil, redirectHistory: nil, isUserInitiated: true, sourceFrame: FrameInfo(frame: WKFrameInfo()), targetFrame: nil, shouldDownload: false, mainFrameNavigation: nil)
        let navigation = Navigation(identity: .init(nil), responders: .init(), state: .started, redirectHistory: [action], isCurrent: true, isCommitted: true)
        let mockWebView = MockWKWebView(url: URL(string: errorURLString)!)
        mockWebViewPublisher.send(mockWebView)
        // errorPageExtention.leaveSiteAction()

        // WHEN
        let disposition = await errorPageExtention.didReceive(URLAuthenticationChallenge(protectionSpace: protectionSpace, proposedCredential: nil, previousFailureCount: 0, failureResponse: nil, error: nil, sender: ChallangeSender()), for: navigation)

        // THEN
        XCTAssertNil(disposition)
    }

    @MainActor
    func testWhenDidReceiveChallange_IfChallangeNotForCertificateValidation_AndUserDoesNotRequestBypass_AndNavigationURLIsNotTheSameAsWebViewURL_ThenReturnsNoCredentials() async {
        // GIVEN
        let protectionSpace = URLProtectionSpace(host: "", port: 4, protocol: nil, realm: nil, authenticationMethod: NSURLAuthenticationMethodServerTrust)
        let action = NavigationAction(request: URLRequest(url: URL(string: "com.different.error")!), navigationType: .custom(.userEnteredUrl), currentHistoryItemIdentity: nil, redirectHistory: nil, isUserInitiated: true, sourceFrame: FrameInfo(frame: WKFrameInfo()), targetFrame: nil, shouldDownload: false, mainFrameNavigation: nil)
        let navigation = Navigation(identity: .init(nil), responders: .init(), state: .started, redirectHistory: [action], isCurrent: true, isCommitted: true)
        let mockWebView = MockWKWebView(url: URL(string: errorURLString)!)
        mockWebViewPublisher.send(mockWebView)
        errorPageExtention.visitSiteAction()

        // WHEN
        let disposition = await errorPageExtention.didReceive(URLAuthenticationChallenge(protectionSpace: protectionSpace, proposedCredential: nil, previousFailureCount: 0, failureResponse: nil, error: nil, sender: ChallangeSender()), for: navigation)

        // THEN
        XCTAssertNil(disposition)
    }

    @MainActor func testWhenPhishingDetected_ThenPhishingErrorPageIsShown() async {
        // GIVEN
        let mockWebView = MockWKWebView(url: URL(string: phishingURLString)!)
        let mainFrameNavigation = Navigation(identity: NavigationIdentity(nil), responders: ResponderChain(), state: .started, isCurrent: true)
        let urlRequest = URLRequest(url: URL(string: phishingURLString)!)
        let mainFrameTarget = FrameInfo(webView: nil, handle: FrameHandle(rawValue: 1 as UInt64)!, isMainFrame: true, url: URL(string: phishingURLString)!, securityOrigin: .empty)
        let navigationAction = NavigationAction(request: urlRequest, navigationType: .custom(.userEnteredUrl), currentHistoryItemIdentity: nil, redirectHistory: [NavigationAction](), isUserInitiated: true, sourceFrame: FrameInfo(frame: WKFrameInfo()), targetFrame: mainFrameTarget, shouldDownload: false, mainFrameNavigation: mainFrameNavigation)
        var preferences = NavigationPreferences(userAgent: "dummy", contentMode: .desktop, javaScriptEnabled: true)
        mockWebViewPublisher.send(mockWebView)

        // WHEN
        let policy = await errorPageExtention.decidePolicy(for: navigationAction, preferences: &preferences)

        // THEN
        XCTAssertEqual(policy.debugDescription, "redirect")
        XCTAssertEqual(errorPageExtention.state.currentMalicousSiteThreatKind, .phishing)
        XCTAssertNil(errorPageExtention.state.bypassedMaliciousSiteThreatKind)
    }

    @MainActor func testWhenPhishingDetected_AndVisitSiteClicked_ThenNavigationProceeds() async {
        // GIVEN
        let mockWebView = MockWKWebView(url: URL(string: phishingURLString)!)
        let mainFrameNavigation = Navigation(identity: NavigationIdentity(nil), responders: ResponderChain(), state: .started, isCurrent: true)
        let urlRequest = URLRequest(url: URL(string: phishingURLString)!)
        let mainFrameTarget = FrameInfo(webView: nil, handle: FrameHandle(rawValue: 1 as UInt64)!, isMainFrame: true, url: URL(string: phishingURLString)!, securityOrigin: .empty)
        let navigationAction = NavigationAction(request: urlRequest, navigationType: .custom(.userEnteredUrl), currentHistoryItemIdentity: nil, redirectHistory: [NavigationAction](), isUserInitiated: true, sourceFrame: FrameInfo(frame: WKFrameInfo()), targetFrame: mainFrameTarget, shouldDownload: false, mainFrameNavigation: mainFrameNavigation)
        var preferences = NavigationPreferences(userAgent: "dummy", contentMode: .desktop, javaScriptEnabled: true)
        mockWebViewPublisher.send(mockWebView)
        _ = await errorPageExtention.decidePolicy(for: navigationAction, preferences: &preferences)
        errorPageExtention.navigation(mainFrameNavigation, didFailWith: WKError(_nsError: MaliciousSiteError(code: .phishing, failingUrl: URL(string: phishingURLString)!) as NSError))

        // WHEN
        errorPageExtention.visitSiteAction()
        let policy = await errorPageExtention.decidePolicy(for: navigationAction, preferences: &preferences)

        // THEN
        XCTAssertEqual(policy.debugDescription, "next")
        XCTAssertTrue(mockWebView.reloadCalled)
        XCTAssertTrue(mockWebView.canGoBack)
        XCTAssertNil(errorPageExtention.state.currentMalicousSiteThreatKind)
        XCTAssertEqual(errorPageExtention.state.bypassedMaliciousSiteThreatKind, .phishing)
    }

    @MainActor func testWhenPhishingNotDetected_ThenNavigationProceeds() async {
         // GIVEN
        detector.isMalicious = { _ in .none }
         let mockWebView = MockWKWebView(url: URL(string: phishingURLString)!)
        let mainFrameNavigation = Navigation(identity: NavigationIdentity(nil), responders: ResponderChain(), state: .started, isCurrent: true)
        let urlRequest = URLRequest(url: URL(string: phishingURLString)!)
        let mainFrameTarget = FrameInfo(webView: nil, handle: FrameHandle(rawValue: 1 as UInt64)!, isMainFrame: true, url: URL(string: phishingURLString)!, securityOrigin: .empty)
        let navigationAction = NavigationAction(request: urlRequest, navigationType: .custom(.userEnteredUrl), currentHistoryItemIdentity: nil, redirectHistory: [NavigationAction](), isUserInitiated: true, sourceFrame: FrameInfo(frame: WKFrameInfo()), targetFrame: mainFrameTarget, shouldDownload: false, mainFrameNavigation: mainFrameNavigation)
        var preferences = NavigationPreferences(userAgent: "dummy", contentMode: .desktop, javaScriptEnabled: true)
        mockWebViewPublisher.send(mockWebView)

        // WHEN
        let policy = await errorPageExtention.decidePolicy(for: navigationAction, preferences: &preferences)

        // THEN
        XCTAssertEqual(policy.debugDescription, "next")
        XCTAssertFalse(mockWebView.reloadCalled)
        XCTAssertNil(errorPageExtention.state.currentMalicousSiteThreatKind)
        XCTAssertNil(errorPageExtention.state.bypassedMaliciousSiteThreatKind)
     }
}

class MockWKWebView: NSObject, ErrorPageTabExtensionNavigationDelegate {
    var canGoBack: Bool = true
    var url: URL?
    var capturedHTML: String = ""
    var goBackCalled = false
    var reloadCalled = false
    var openNewTabCalled = false
    var closedCalled = false
    var loadCalled = false

    init(url: URL) {
        self.url = url
    }

    func loadAlternateHTML(_ html: String, baseURL: URL, forUnreachableURL failingURL: URL) {
        capturedHTML = html
    }

    func setDocumentHtml(_ html: String) {
        capturedHTML = html
    }

    func goBack() -> WKNavigation? {
        goBackCalled = true
        return nil
    }

    func reloadPageFromErrorPage() {
        reloadCalled = true
    }

    @MainActor func openNewTabFromErrorPage() async {
        openNewTabCalled = true
    }

    func close() {
        closedCalled = true
    }

    func load(_ request: URLRequest) -> WKNavigation? {
        loadCalled = true
        return .none
    }
}

class MockSpecialErrorPageScriptProvider: SpecialErrorPageScriptProvider {
    var specialErrorPageUserScript: SpecialErrorPageUserScript?

    init(script: SpecialErrorPageUserScript?) {
        self.specialErrorPageUserScript = script
    }
}

class MockCredentialCreator: URLCredentialCreating {
    func urlCredentialFrom(trust: SecTrust?) -> URLCredential? {
        return URLCredential(user: "", password: "", persistence: .forSession)
    }
}

class ChallangeSender: URLAuthenticationChallengeSender {
    func use(_ credential: URLCredential, for challenge: URLAuthenticationChallenge) {}
    func continueWithoutCredential(for challenge: URLAuthenticationChallenge) {}
    func cancel(_ challenge: URLAuthenticationChallenge) {}
    func isEqual(_ object: Any?) -> Bool {
        return false
    }
    var hash: Int = 0
    var superclass: AnyClass?
    func `self`() -> Self {
        self
    }
    func perform(_ aSelector: Selector!) -> Unmanaged<AnyObject>! {
        return nil
    }
    func perform(_ aSelector: Selector!, with object: Any!) -> Unmanaged<AnyObject>! {
        return nil
    }
    func perform(_ aSelector: Selector!, with object1: Any!, with object2: Any!) -> Unmanaged<AnyObject>! {
        return nil
    }
    func isProxy() -> Bool {
        return false
    }
    func isKind(of aClass: AnyClass) -> Bool {
        return false
    }
    func isMember(of aClass: AnyClass) -> Bool {
        return false
    }
    func conforms(to aProtocol: Protocol) -> Bool {
        return false
    }
    func responds(to aSelector: Selector!) -> Bool {
        return false
    }
    var description: String = ""
}

class MockFeatureFlagger: FeatureFlagger {
    var internalUserDecider: InternalUserDecider = DefaultInternalUserDecider(store: MockInternalUserStoring())
    var localOverrides: FeatureFlagLocalOverriding?
    var cohort: (any FeatureFlagCohortDescribing)?

    var isFeatureOn = true
    func isFeatureOn<Flag: FeatureFlagDescribing>(for featureFlag: Flag, allowOverride: Bool) -> Bool {
        return isFeatureOn
    }

    func getCohortIfEnabled(_ subfeature: any PrivacySubfeature) -> CohortID? {
        return nil
    }

    func resolveCohort<Flag>(for featureFlag: Flag, allowOverride: Bool) -> (any FeatureFlagCohortDescribing)? where Flag: FeatureFlagDescribing {
        return cohort
    }

    var allActiveExperiments: Experiments = [:]
}
