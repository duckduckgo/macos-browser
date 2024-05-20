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
import Navigation
import Common
import WebKit
import XCTest

@testable import DuckDuckGo_Privacy_Browser

final class ErrorPageTabExtensionTest: XCTestCase {

    var mockWebViewPublisher: PassthroughSubject<WKWebView, Never>!
    var scriptPublisher: PassthroughSubject<MockSpecialErrorPageScriptProvider, Never>!
    var errorPageExtention: SpecialErrorPageTabExtension!
    var credentialCreator: MockCredentialCreator!
    let errorURLString = "com.example.error"

    override func setUpWithError() throws {
        mockWebViewPublisher = PassthroughSubject<WKWebView, Never>()
        scriptPublisher = PassthroughSubject<MockSpecialErrorPageScriptProvider, Never>()
        credentialCreator = MockCredentialCreator()
        let featureFlagger = MockFeatureFlagger()
        errorPageExtention = SpecialErrorPageTabExtension(webViewPublisher: mockWebViewPublisher, scriptsPublisher: scriptPublisher, urlCredentialCreator: credentialCreator, featureFlagger: featureFlagger)
    }

    override func tearDownWithError() throws {
        mockWebViewPublisher = nil
        scriptPublisher = nil
        errorPageExtention = nil
        credentialCreator = nil
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
        let eTldPlus1 = TLD().eTLDplus1(errorURLString) ?? errorURLString

        // WHEN
        errorPageExtention.navigation(navigation, didFailWith: error)

        // THEN
        let expectedSpecificMessage = SpecialErrorType.expired.specificMessage(for: errorURLString, eTldPlus1: eTldPlus1).replacingOccurrences(of: "</b>", with: "<\\/b>").escapedUnicodeHtmlString()
        XCTAssertTrue(mockWebView.capturedHTML.contains(expectedSpecificMessage))
    }

    @MainActor func testWhenCertificateSelfSigned_ThenExpectedErrorPageIsShown() {
        // GIVEN
        let mockWebView = MockWKWebView(url: URL(string: errorURLString)!)
        errorPageExtention.webView = mockWebView
        let error = WKError(_nsError: NSError(domain: "com.example.error", code: NSURLErrorServerCertificateUntrusted, userInfo: ["_kCFStreamErrorCodeKey": -9807, "NSErrorFailingURLKey": URL(string: errorURLString)!]))
        let navigation = Navigation(identity: .init(nil), responders: .init(), state: .started, redirectHistory: [], isCurrent: true, isCommitted: true)
        let eTldPlus1 = TLD().eTLDplus1(errorURLString) ?? errorURLString

        // WHEN
        errorPageExtention.navigation(navigation, didFailWith: error)

        // THEN
        let expectedSpecificMessage = SpecialErrorType.selfSigned.specificMessage(for: errorURLString, eTldPlus1: eTldPlus1).replacingOccurrences(of: "</b>", with: "<\\/b>").escapedUnicodeHtmlString()
        XCTAssertTrue(mockWebView.capturedHTML.contains(expectedSpecificMessage))
    }

    @MainActor func testWhenCertificateWrongHost_ThenExpectedErrorPageIsShown() {
        // GIVEN
        let mockWebView = MockWKWebView(url: URL(string: errorURLString)!)
        errorPageExtention.webView = mockWebView
        let error = WKError(_nsError: NSError(domain: "com.example.error", code: NSURLErrorServerCertificateUntrusted, userInfo: ["_kCFStreamErrorCodeKey": -9843, "NSErrorFailingURLKey": URL(string: errorURLString)!]))
        let navigation = Navigation(identity: .init(nil), responders: .init(), state: .started, redirectHistory: [], isCurrent: true, isCommitted: true)
        let eTldPlus1 = TLD().eTLDplus1(errorURLString) ?? errorURLString

        // WHEN
        errorPageExtention.navigation(navigation, didFailWith: error)

        // THEN
        let expectedSpecificMessage = SpecialErrorType.wrongHost.specificMessage(for: errorURLString, eTldPlus1: eTldPlus1).replacingOccurrences(of: "</b>", with: "<\\/b>").escapedUnicodeHtmlString()
        XCTAssertTrue(mockWebView.capturedHTML.contains(expectedSpecificMessage))

    }

    @MainActor func test_WhenUserScriptsPublisherPublishSpecialErrorPageScript_ThenErrorPageExtensionIsSetAsUserScriptDelegate() {
        // GIVEN
        let aSpecialErrorUserScript = SpecialErrorPageUserScript()
        let mockScriptProvider = MockSpecialErrorPageScriptProvider(script: aSpecialErrorUserScript)

        // WHEN
        scriptPublisher.send(mockScriptProvider)

        // THEN
        XCTAssertNotNil(aSpecialErrorUserScript.delegate)
    }

    @MainActor func testWhenNavigationEnded_IfNoFailure_SSLUserScriptIsNotEnabled() {
        // GIVEN
        let userScript = SpecialErrorPageUserScript()
        let mockScriptProvider = MockSpecialErrorPageScriptProvider(script: userScript)
        let mockWebView = MockWKWebView(url: URL(string: errorURLString)!)
        let action = NavigationAction(request: URLRequest(url: URL(string: "com.example.error")!), navigationType: .custom(.userEnteredUrl), currentHistoryItemIdentity: nil, redirectHistory: nil, isUserInitiated: true, sourceFrame: FrameInfo(frame: WKFrameInfo()), targetFrame: nil, shouldDownload: false, mainFrameNavigation: nil)
        let navigation = Navigation(identity: .init(nil), responders: .init(), state: .started, redirectHistory: [action], isCurrent: true, isCommitted: true)
        errorPageExtention.webView = mockWebView
        scriptPublisher.send(mockScriptProvider)

        // WHEN
        errorPageExtention.navigationDidFinish(navigation)

        // THEN
        XCTAssertFalse(userScript.isEnabled)
        XCTAssertNil(userScript.failingURL)
    }

    @MainActor func testWhenNavigationEnded_IfNonSSLFailure_SSLUserScriptIsNotEnabled() {
        // GIVEN
        let userScript = SpecialErrorPageUserScript()
        let mockScriptProvider = MockSpecialErrorPageScriptProvider(script: userScript)
        let mockWebView = MockWKWebView(url: URL(string: errorURLString)!)
        let action = NavigationAction(request: URLRequest(url: URL(string: "com.example.error")!), navigationType: .custom(.userEnteredUrl), currentHistoryItemIdentity: nil, redirectHistory: nil, isUserInitiated: true, sourceFrame: FrameInfo(frame: WKFrameInfo()), targetFrame: nil, shouldDownload: false, mainFrameNavigation: nil)
        let navigation = Navigation(identity: .init(nil), responders: .init(), state: .started, redirectHistory: [action], isCurrent: true, isCommitted: true)
        let errorDescription = "some error"
        let error = WKError(_nsError: NSError(domain: "com.example.error", code: NSURLErrorUnknown, userInfo: ["_kCFStreamErrorCodeKey": -9843, "NSErrorFailingURLKey": URL(string: errorURLString)!, NSLocalizedDescriptionKey: errorDescription]))
        errorPageExtention.webView = mockWebView
        scriptPublisher.send(mockScriptProvider)
        errorPageExtention.navigation(navigation, didFailWith: error)

        // WHEN
        errorPageExtention.navigationDidFinish(navigation)

        // THEN
        XCTAssertFalse(userScript.isEnabled)
        XCTAssertNil(userScript.failingURL)
    }

    @MainActor func testWhenNavigationEnded_IfSSLFailure_AndErrorURLIsDifferentFromNavigationURL_SSLUserScriptIsNotEnabled() {
        // GIVEN
        let userScript = SpecialErrorPageUserScript()
        let mockScriptProvider = MockSpecialErrorPageScriptProvider(script: userScript)
        let mockWebView = MockWKWebView(url: URL(string: errorURLString)!)
        let action = NavigationAction(request: URLRequest(url: URL(string: "com.different.error")!), navigationType: .custom(.userEnteredUrl), currentHistoryItemIdentity: nil, redirectHistory: nil, isUserInitiated: true, sourceFrame: FrameInfo(frame: WKFrameInfo()), targetFrame: nil, shouldDownload: false, mainFrameNavigation: nil)
        let navigation = Navigation(identity: .init(nil), responders: .init(), state: .started, redirectHistory: [action], isCurrent: true, isCommitted: true)
        let error = WKError(_nsError: NSError(domain: "com.example.error", code: NSURLErrorServerCertificateUntrusted, userInfo: ["_kCFStreamErrorCodeKey": -9843, "NSErrorFailingURLKey": URL(string: errorURLString)!]))
        errorPageExtention.webView = mockWebView
        scriptPublisher.send(mockScriptProvider)
        errorPageExtention.navigation(navigation, didFailWith: error)

        // WHEN
        errorPageExtention.navigationDidFinish(navigation)

        // THEN
        XCTAssertFalse(userScript.isEnabled)
        XCTAssertEqual(userScript.failingURL?.absoluteString, errorURLString)
    }

    @MainActor func testWhenNavigationEnded_IfSSLFailure_AndErrorURLIsTheSameAsNavigationURL_SSLUserScriptIsEnabled() {
        // GIVEN
        let userScript = SpecialErrorPageUserScript()
        let mockScriptProvider = MockSpecialErrorPageScriptProvider(script: userScript)
        let mockWebView = MockWKWebView(url: URL(string: errorURLString)!)
        let action = NavigationAction(request: URLRequest(url: URL(string: "com.example.error")!), navigationType: .custom(.userEnteredUrl), currentHistoryItemIdentity: nil, redirectHistory: nil, isUserInitiated: true, sourceFrame: FrameInfo(frame: WKFrameInfo()), targetFrame: nil, shouldDownload: false, mainFrameNavigation: nil)
        let navigation = Navigation(identity: .init(nil), responders: .init(), state: .started, redirectHistory: [action], isCurrent: true, isCommitted: true)
        let error = WKError(_nsError: NSError(domain: "com.example.error", code: NSURLErrorServerCertificateUntrusted, userInfo: ["_kCFStreamErrorCodeKey": -9843, "NSErrorFailingURLKey": URL(string: errorURLString)!]))
        errorPageExtention.webView = mockWebView
        scriptPublisher.send(mockScriptProvider)
        errorPageExtention.navigation(navigation, didFailWith: error)

        // WHEN
        errorPageExtention.navigationDidFinish(navigation)

        // THEN
        XCTAssertTrue(userScript.isEnabled)
        XCTAssertEqual(userScript.failingURL?.absoluteString, errorURLString)
    }

    func testWhenLeaveSiteCalled_AndCanGoBackTrue_ThenWebViewGoesBack() {
        // GIVEN
        let mockWebView = MockWKWebView(url: URL(string: errorURLString)!)
        errorPageExtention.webView = mockWebView

        // WHEN
        errorPageExtention.leaveSite()

        // THEN
        XCTAssertTrue(mockWebView.goBackCalled)
    }

    func testWhenLeaveSiteCalled_AndCanGoBackFalse_ThenWebViewCloses() {
        // GIVEN
        let mockWebView = MockWKWebView(url: URL(string: errorURLString)!)
        mockWebView.canGoBack = false
        errorPageExtention.webView = mockWebView

        // WHEN
        errorPageExtention.leaveSite()

        // THEN
        XCTAssertTrue(mockWebView.closedCalled)
    }

    func testWhenVisitSiteCalled_ThenWebViewReloads() {
        // GIVEN
        let mockWebView = MockWKWebView(url: URL(string: errorURLString)!)
        errorPageExtention.webView = mockWebView

        // WHEN
        errorPageExtention.visitSite()

        // THEN
        XCTAssertTrue(mockWebView.reloadCalled)
    }

    @MainActor
    func testWhenDidReceiveChallange_IfChallangeForCertificateValidation_AndUserRequestBypass_AndNavigationURLIsTheSameAsWevViewURL_ThenReturnsCredentials() async {
        // GIVEN
        let protectionSpace = URLProtectionSpace(host: "", port: 4, protocol: nil, realm: nil, authenticationMethod: NSURLAuthenticationMethodServerTrust)
        let action = NavigationAction(request: URLRequest(url: URL(string: "com.example.error")!), navigationType: .custom(.userEnteredUrl), currentHistoryItemIdentity: nil, redirectHistory: nil, isUserInitiated: true, sourceFrame: FrameInfo(frame: WKFrameInfo()), targetFrame: nil, shouldDownload: false, mainFrameNavigation: nil)
        let navigation = Navigation(identity: .init(nil), responders: .init(), state: .started, redirectHistory: [action], isCurrent: true, isCommitted: true)
        let mockWebView = MockWKWebView(url: URL(string: errorURLString)!)
        errorPageExtention.webView = mockWebView
        errorPageExtention.visitSite()

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
    func testWhenDidReceiveChallange_IfChallangeNotForCertificateValidation_AndUserRequestBypass_AndNavigationURLIsTheSameAsWevViewURL_ThenReturnsNoCredentials() async {
        // GIVEN
        let protectionSpace = URLProtectionSpace(host: "", port: 4, protocol: nil, realm: nil, authenticationMethod: NSURLAuthenticationMethodClientCertificate)
        let action = NavigationAction(request: URLRequest(url: URL(string: "com.example.error")!), navigationType: .custom(.userEnteredUrl), currentHistoryItemIdentity: nil, redirectHistory: nil, isUserInitiated: true, sourceFrame: FrameInfo(frame: WKFrameInfo()), targetFrame: nil, shouldDownload: false, mainFrameNavigation: nil)
        let navigation = Navigation(identity: .init(nil), responders: .init(), state: .started, redirectHistory: [action], isCurrent: true, isCommitted: true)
        let mockWebView = MockWKWebView(url: URL(string: errorURLString)!)
        errorPageExtention.webView = mockWebView
        errorPageExtention.visitSite()

        // WHEN
        let disposition = await errorPageExtention.didReceive(URLAuthenticationChallenge(protectionSpace: protectionSpace, proposedCredential: nil, previousFailureCount: 0, failureResponse: nil, error: nil, sender: ChallangeSender()), for: navigation)

        // THEN
        XCTAssertNil(disposition)
    }

    @MainActor
    func testWhenDidReceiveChallange_IfChallangeForCertificateValidation_AndUserDoesNotRequestBypass_AndNavigationURLIsTheSameAsWevViewURL_ThenReturnsNoCredentials() async {
        // GIVEN
        let protectionSpace = URLProtectionSpace(host: "", port: 4, protocol: nil, realm: nil, authenticationMethod: NSURLAuthenticationMethodServerTrust)
        let action = NavigationAction(request: URLRequest(url: URL(string: "com.example.error")!), navigationType: .custom(.userEnteredUrl), currentHistoryItemIdentity: nil, redirectHistory: nil, isUserInitiated: true, sourceFrame: FrameInfo(frame: WKFrameInfo()), targetFrame: nil, shouldDownload: false, mainFrameNavigation: nil)
        let navigation = Navigation(identity: .init(nil), responders: .init(), state: .started, redirectHistory: [action], isCurrent: true, isCommitted: true)
        let mockWebView = MockWKWebView(url: URL(string: errorURLString)!)
        errorPageExtention.webView = mockWebView
        errorPageExtention.leaveSite()

        // WHEN
        let disposition = await errorPageExtention.didReceive(URLAuthenticationChallenge(protectionSpace: protectionSpace, proposedCredential: nil, previousFailureCount: 0, failureResponse: nil, error: nil, sender: ChallangeSender()), for: navigation)

        // THEN
        XCTAssertNil(disposition)
    }

    @MainActor
    func testWhenDidReceiveChallange_IfChallangeNotForCertificateValidation_AndUserDoesNotRequestBypass_AndNavigationURLIsNotTheSameAsWevViewURL_ThenReturnsNoCredentials() async {
        // GIVEN
        let protectionSpace = URLProtectionSpace(host: "", port: 4, protocol: nil, realm: nil, authenticationMethod: NSURLAuthenticationMethodServerTrust)
        let action = NavigationAction(request: URLRequest(url: URL(string: "com.different.error")!), navigationType: .custom(.userEnteredUrl), currentHistoryItemIdentity: nil, redirectHistory: nil, isUserInitiated: true, sourceFrame: FrameInfo(frame: WKFrameInfo()), targetFrame: nil, shouldDownload: false, mainFrameNavigation: nil)
        let navigation = Navigation(identity: .init(nil), responders: .init(), state: .started, redirectHistory: [action], isCurrent: true, isCommitted: true)
        let mockWebView = MockWKWebView(url: URL(string: errorURLString)!)
        errorPageExtention.webView = mockWebView
        errorPageExtention.visitSite()

        // WHEN
        let disposition = await errorPageExtention.didReceive(URLAuthenticationChallenge(protectionSpace: protectionSpace, proposedCredential: nil, previousFailureCount: 0, failureResponse: nil, error: nil, sender: ChallangeSender()), for: navigation)

        // THEN
        XCTAssertNil(disposition)
    }

}

class MockWKWebView: NSObject, ErrorPageTabExtensionNavigationDelegate {
    var canGoBack: Bool = true
    var url: URL?
    var capturedHTML: String = ""
    var goBackCalled = false
    var reloadCalled = false
    var closedCalled = false

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

    func reloadPage() -> WKNavigation? {
        reloadCalled = true
        return nil
    }

    func close() {
        closedCalled = true
    }
}

class MockSpecialErrorPageScriptProvider: SpecialErrorPageScriptProvider {
    var SpecialErrorPageUserScript: SpecialErrorPageUserScript?

    init(script: SpecialErrorPageUserScript?) {
        self.SpecialErrorPageUserScript = script
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
    func isFeatureOn<F>(forProvider: F) -> Bool where F: BrowserServicesKit.FeatureFlagSourceProviding {
        return true
    }
}
