//
//  MaliciousSiteProtectionIntegrationTests.swift
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

@available(macOS 12.0, *)
class MaliciousSiteProtectionIntegrationTests: XCTestCase {

    var window: NSWindow!
    var cancellables: Set<AnyCancellable>!
    var detector: MaliciousSiteDetecting!
    var contentBlockingMock: ContentBlockingMock!
    var privacyFeaturesMock: AnyPrivacyFeatures!
    var privacyConfiguration: MockPrivacyConfiguration {
        contentBlockingMock.privacyConfigurationManager.privacyConfig as! MockPrivacyConfiguration
    }
    var tab: Tab!
    var tabViewModel: TabViewModel!
    var schemeHandler: TestSchemeHandler!

    @MainActor
    override func setUp() async throws {
        WebTrackingProtectionPreferences.shared.isGPCEnabled = false
        MaliciousSiteProtectionPreferences.shared.isEnabled = true
        let featureFlagger = MockFeatureFlagger()
        let configManager = MockPrivacyConfigurationManager()
        let configuration = MockPrivacyConfiguration()
        configuration.featureSettings[MaliciousSiteProtectionRemoteSettings.Key<TimeInterval>.hashPrefixUpdateFrequencyMinutes.rawValue] = -1
        configuration.featureSettings[MaliciousSiteProtectionRemoteSettings.Key<TimeInterval>.filterSetUpdateFrequencyMinutes.rawValue] = -1
        configManager.privacyConfig = configuration

        detector = MaliciousSiteProtectionManager(featureFlagger: featureFlagger, configManager: configManager)
        schemeHandler = TestSchemeHandler()
        schemeHandler.middleware = [{
            if $0.url!.lastPathComponent == "phishing.html" {
                XCTFail("Phishing request loaded")
            }
            return .ok(.html(""))
        }]

        WKWebView.customHandlerSchemes = [.http, .https]

        let webViewConfiguration = WKWebViewConfiguration()
        webViewConfiguration.setURLSchemeHandler(schemeHandler, forURLScheme: URL.NavigationalScheme.http.rawValue)
        webViewConfiguration.setURLSchemeHandler(schemeHandler, forURLScheme: URL.NavigationalScheme.https.rawValue)

        contentBlockingMock = ContentBlockingMock()
        privacyFeaturesMock = AppPrivacyFeatures(contentBlocking: contentBlockingMock, httpsUpgradeStore: HTTPSUpgradeStoreMock())
        // disable waiting for CBR compilation on navigation
        privacyConfiguration.isFeatureKeyEnabled = { feature, _ in
            if case .maliciousSiteProtection = feature { true } else { false }
        }

        tab = Tab(content: .none, webViewConfiguration: webViewConfiguration, privacyFeatures: privacyFeaturesMock, maliciousSiteDetector: detector)
        tabViewModel = TabViewModel(tab: tab)
        window = WindowsManager.openNewWindow(with: tab)!
        cancellables = Set<AnyCancellable>()
    }

    @MainActor
    override func tearDown() async throws {
        window.close()
        window = nil
        cancellables = nil
        detector = nil
        tab = nil
        tabViewModel = nil
        schemeHandler = nil
        WKWebView.customHandlerSchemes = []
        WebTrackingProtectionPreferences.shared.isGPCEnabled = true
    }

    // MARK: - Tests

    @MainActor
    func testPhishingNotDetected_tabIsNotMarkedPhishing() async throws {
        let url = URL(string: "http://privacy-test-pages.site/")!
        try await loadUrl(url)
        XCTAssertNil(tabViewModel.tab.error)
    }

    @MainActor
    func testPhishingDetected_tabIsMarkedPhishing() async throws {
        let url = URL(string: "http://privacy-test-pages.site/security/badware/phishing.html")!
        try await loadUrl(url)
        XCTAssertEqual(tabViewModel.tab.error as NSError? as? MaliciousSiteError, MaliciousSiteError(code: .phishing, failingUrl: url))
    }

    @MainActor
    func testFeatureDisabledAndPhishingDetection_tabIsNotMarkedPhishing() async throws {
        MaliciousSiteProtectionPreferences.shared.isEnabled = false
        let e = expectation(description: "request sent")
        schemeHandler.middleware = [{ _ in
            e.fulfill()
            return .ok(.html(""))
        }]
        let url = URL(string: "http://privacy-test-pages.site/security/badware/phishing.html")!
        try await loadUrl(url)
        await fulfillment(of: [e], timeout: 1)
        XCTAssertNil(tabViewModel.tab.error)
    }

    @MainActor
    func testPhishingDetectedThenNotDetected_tabIsNotMarkedPhishing() async throws {
        let url1 = URL(string: "http://privacy-test-pages.site/security/badware/phishing.html")!
        try await loadUrl(url1)
        XCTAssertEqual(tabViewModel.tab.error as NSError? as? MaliciousSiteError, MaliciousSiteError(code: .phishing, failingUrl: url1))

        let url2 = URL(string: "http://broken.third-party.site/")!
        try await loadUrl(url2)
        XCTAssertNil(tabViewModel.tab.error)
    }

    @MainActor
    func testPhishingDetectedThenDDGLoaded_tabIsNotMarkedPhishing() async throws {
        let url1 = URL(string: "http://privacy-test-pages.site/security/badware/phishing.html")!
        try await loadUrl(url1)
        XCTAssertEqual(tabViewModel.tab.error as NSError? as? MaliciousSiteError, MaliciousSiteError(code: .phishing, failingUrl: url1))

        let url2 = URL(string: "http://duckduckgo.com/")!
        try await loadUrl(url2)
        let tabErrorCode2 = tabViewModel.tab.error?.errorCode
        XCTAssertNil(tabErrorCode2)
    }

    @MainActor
    func testPhishingDetectedViaHTTPRedirectChain_tabIsMarkedPhishing() async throws {
        let eRedirected = expectation(description: "Request redirected")
        let url = URL(string: "http://privacy-test-pages.site/security/badware/phishing-redirect/")!
        let redirectUrl = URL(string: "http://privacy-test-pages.site/security/badware/phishing.html")!

        schemeHandler.middleware = [{
            if $0.url?.lastPathComponent == "phishing-redirect" {
                eRedirected.fulfill()
                return .redirect(to: "/security/badware/phishing.html")
            }
            XCTFail("\(self.name): Phishing request loaded")
            return nil
        }]
        try await loadUrl(url)
        await fulfillment(of: [eRedirected], timeout: 0)

        XCTAssertEqual(tabViewModel.tab.error as NSError? as? MaliciousSiteError, MaliciousSiteError(code: .phishing, failingUrl: redirectUrl))
    }

    @MainActor
    func testPhishingDetectedViaJSRedirectChain_tabIsMarkedPhishing() async throws {
        let eRequested = expectation(description: "Request sent")
        let url = URL(string: "http://my-test-pages.site/security/badware/phishing-js-redirector.html")!
        let redirectUrl = URL(string: "http://privacy-test-pages.site/security/badware/phishing.html")!

        schemeHandler.middleware = [{
            if $0.url?.lastPathComponent == "phishing-js-redirector.html" {
                eRequested.fulfill()
                return .ok(.html("""
                <html>
                <head>
                    <script>
                        window.location = 'http://privacy-test-pages.site/security/badware/phishing.html';
                    </script>
                </head>
                </html>
                """))
            }
            XCTFail("\(self.name): Phishing request loaded for \($0.url!.absoluteString)")
            return nil
        }]
        try await loadUrl(url)
        await fulfillment(of: [eRequested], timeout: 0)
        await wait { self.tab.error != nil }

        XCTAssertEqual(tabViewModel.tab.error as NSError? as? MaliciousSiteError, MaliciousSiteError(code: .phishing, failingUrl: redirectUrl))
    }

    // MARK: - Helper Methods

    @MainActor
    private func loadUrl(_ url: URL) async throws {
        tab.setUrl(url, source: .link)
        await wait { !self.tab.isLoading }
    }

    @MainActor
    func wait(until condition: @escaping () -> Bool) async {
        let loadingExpectation = expectation(description: "Tab finished loading")
        let task = Task {
            while !condition() {
                try Task.checkCancellation()
                await Task.yield()
            }
            loadingExpectation.fulfill()
        }
        defer { task.cancel() }
        await fulfillment(of: [loadingExpectation], timeout: 1)
    }
}

class MockFeatureFlagger: FeatureFlagger {
    var internalUserDecider: InternalUserDecider = DefaultInternalUserDecider(store: MockInternalUserStoring())
    var localOverrides: FeatureFlagLocalOverriding?

    func isFeatureOn<Flag: FeatureFlagDescribing>(for featureFlag: Flag, allowOverride: Bool) -> Bool {
        return true
    }

    func getCohortIfEnabled(_ subfeature: any PrivacySubfeature) -> CohortID? {
        return nil
    }

    func getCohortIfEnabled<Flag>(for featureFlag: Flag) -> (any FlagCohort)? where Flag: FeatureFlagExperimentDescribing {
        return nil
    }

    func getAllActiveExperiments() -> Experiments {
        return [:]
    }

}
