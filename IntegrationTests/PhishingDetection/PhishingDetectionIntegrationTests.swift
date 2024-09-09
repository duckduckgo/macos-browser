//
//  PhishingDetectionIntegrationTests.swift
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

import Combine
import Common
import XCTest
import BrowserServicesKit
import PhishingDetection

@testable import DuckDuckGo_Privacy_Browser

@available(macOS 12.0, *)
class PhishingDetectionIntegrationTests: XCTestCase {

    var window: NSWindow!
    var cancellables: Set<AnyCancellable>!
    var phishingDetector: PhishingSiteDetecting!
    var tab: Tab!
    var tabViewModel: TabViewModel!

    @MainActor
    override func setUp() {
        super.setUp()
        WebTrackingProtectionPreferences.shared.isGPCEnabled = false
        PhishingDetectionPreferences.shared.isEnabled = true
        let featureFlagger = MockFeatureFlagger()
        phishingDetector = PhishingDetection(featureFlagger: featureFlagger, configManager: MockPrivacyConfigurationManager())
        tab = Tab(content: .none, phishingDetector: phishingDetector)
        tabViewModel = TabViewModel(tab: tab)
        window = WindowsManager.openNewWindow(with: tab)!
        cancellables = Set<AnyCancellable>()
    }

    @MainActor
    override func tearDown() async throws {
        window.close()
        window = nil
        cancellables = nil
        phishingDetector = nil
        tab = nil
        tabViewModel = nil
        WebTrackingProtectionPreferences.shared.isGPCEnabled = true
        try await super.tearDown()
    }

    // MARK: - Tests

    @MainActor
    func testPhishingNotDetected_tabIsNotMarkedPhishing() async throws {
        loadUrl("http://privacy-test-pages.site/")
        let tabErrorCode2 = tabViewModel.tab.error?.errorCode
        XCTAssertNil(tabErrorCode2)
    }

    @MainActor
    func testPhishingDetected_tabIsMarkedPhishing() async throws {
        loadUrl("http://privacy-test-pages.site/security/badware/phishing.html")
        try await waitForTabToFinishLoading()
        let tabErrorCode = tabViewModel.tab.error?.errorCode
        XCTAssertEqual(tabErrorCode, PhishingDetectionError.detected.errorCode)
    }

    @MainActor
    func testFeatureDisabledAndPhishingDetection_tabIsNotMarkedPhishing() async throws {
        PhishingDetectionPreferences.shared.isEnabled = false
        loadUrl("http://privacy-test-pages.site/security/badware/phishing.html")
        try await waitForTabToFinishLoading()
        let tabErrorCode = tabViewModel.tab.error?.errorCode
        XCTAssertNil(tabErrorCode)
    }

    @MainActor
    func testPhishingDetectedThenNotDetected_tabIsNotMarkedPhishing() async throws {
        loadUrl("http://privacy-test-pages.site/security/badware/phishing.html")
        try await waitForTabToFinishLoading()
        let tabErrorCode = tabViewModel.tab.error?.errorCode
        XCTAssertEqual(tabErrorCode, PhishingDetectionError.detected.errorCode)

        loadUrl("http://broken.third-party.site/")
        try await waitForTabToFinishLoading()
        let tabErrorCode2 = tabViewModel.tab.error?.errorCode
        XCTAssertNil(tabErrorCode2)
    }

    @MainActor
    func testPhishingDetectedThenDDGLoaded_tabIsNotMarkedPhishing() async throws {
        loadUrl("http://privacy-test-pages.site/security/badware/phishing.html")
        try await waitForTabToFinishLoading()
        let tabErrorCode = tabViewModel.tab.error?.errorCode
        XCTAssertEqual(tabErrorCode, PhishingDetectionError.detected.errorCode)

        loadUrl("http://duckduckgo.com/")
        try await waitForTabToFinishLoading()
        let tabErrorCode2 = tabViewModel.tab.error?.errorCode
        XCTAssertNil(tabErrorCode2)
    }

    @MainActor
    func testPhishingDetectedViaHTTPRedirectChain_tabIsMarkedPhishing() async throws {
        loadUrl("http://bad.third-party.site/security/badware/phishing-redirect/")
        try await waitForTabToFinishLoading()
        let tabErrorCode = tabViewModel.tab.error?.errorCode
        XCTAssertEqual(tabErrorCode, PhishingDetectionError.detected.errorCode)
    }

    @MainActor
    func testPhishingDetectedViaJSRedirectChain_tabIsMarkedPhishing() async throws {
        loadUrl("http://bad.third-party.site/security/badware/phishing-js-redirector.html")
        try await waitForTabToFinishLoading()
        let tabErrorCode = tabViewModel.tab.error?.errorCode
        XCTAssertEqual(tabErrorCode, PhishingDetectionError.detected.errorCode)
    }

    // MARK: - Helper Methods

    @MainActor
    private func loadUrl(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        tab.navigateTo(url: url)
    }

    @MainActor
    func waitForTabToFinishLoading() async throws {
        let loadingExpectation = expectation(description: "Tab finished loading")
        Task {
            while tabViewModel.tab.isLoading {
                await Task.yield()
            }
            loadingExpectation.fulfill()
        }
        await fulfillment(of: [loadingExpectation], timeout: 5)
    }
}

class MockFeatureFlagger: FeatureFlagger {
    func isFeatureOn<F>(forProvider: F) -> Bool where F: BrowserServicesKit.FeatureFlagSourceProviding {
        return true
    }
}
