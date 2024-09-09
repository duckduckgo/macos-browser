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
import PhishingDetection

@testable import DuckDuckGo_Privacy_Browser

@available(macOS 12.0, *)
class PhishingDetectionIntegrationTests: XCTestCase {

    var window: NSWindow!
    var cancellables: Set<AnyCancellable>!

    var tabViewModel: TabViewModel {
        (window.contentViewController as! MainViewController).browserTabViewController.tabViewModel!
    }

    @MainActor
    override func setUp() {
        super.setUp()
        WebTrackingProtectionPreferences.shared.isGPCEnabled = false
        PhishingDetectionPreferences.shared.isEnabled = true
        window = WindowsManager.openNewWindow(with: .none)!
        cancellables = Set<AnyCancellable>()
    }

    @MainActor
    override func tearDown() async throws {
        window.close()
        window = nil
        cancellables = nil
        WebTrackingProtectionPreferences.shared.isGPCEnabled = true
        try await super.tearDown()
    }

    // MARK: - Tests

    @MainActor
    func testPhishingNotDetected_tabIsNotMarkedPhishing() async throws {
        try await loadUrl("http://privacy-test-pages.site/")
        let tabErrorCode2 = tabViewModel.tab.error?.errorCode
        XCTAssertNil(tabErrorCode2)
    }

    @MainActor
    func testPhishingDetected_tabIsMarkedPhishing() async throws {
        try await loadUrl("http://privacy-test-pages.site/security/badware/phishing.html")
        let url = URL(string: "http://privacy-test-pages.site/security/badware/phishing.html")!
        let (featureFlagEnabled, preferencesEnabled) = PhishingDetection.shared.isEnabled()
        XCTAssertTrue(featureFlagEnabled, "Internal feature flag should be enabled")
        XCTAssertTrue(preferencesEnabled, "Preferences setting should be enabled")
        let phishingDetected = await PhishingDetection.shared.checkIsMaliciousIfEnabled(url: url)
        XCTAssertTrue(phishingDetected, "PhishingDetection library should return malicious for \(url)")
        try await waitForTabToFinishLoading()
        let tabErrorCode = tabViewModel.tab.error?.errorCode
        XCTAssertEqual(tabErrorCode, PhishingDetectionError.detected.errorCode)
    }

    @MainActor
    func testPhishingDetectedThenNotDetected_tabIsNotMarkedPhishing() async throws {
        try await loadUrl("http://privacy-test-pages.site/security/badware/phishing.html")
        try await waitForTabToFinishLoading()
        let tabErrorCode = tabViewModel.tab.error?.errorCode
        XCTAssertEqual(tabErrorCode, PhishingDetectionError.detected.errorCode)

        try await loadUrl("http://broken.third-party.site/")
        try await waitForTabToFinishLoading()
        let tabErrorCode2 = tabViewModel.tab.error?.errorCode
        XCTAssertNil(tabErrorCode2)
    }

    @MainActor
    func testPhishingDetectedThenDDGLoaded_tabIsNotMarkedPhishing() async throws {
        try await loadUrl("http://privacy-test-pages.site/security/badware/phishing.html")
        try await waitForTabToFinishLoading()
        let tabErrorCode = tabViewModel.tab.error?.errorCode
        XCTAssertEqual(tabErrorCode, PhishingDetectionError.detected.errorCode)

        try await loadUrl("http://duckduckgo.com/")
        try await waitForTabToFinishLoading()
        let tabErrorCode2 = tabViewModel.tab.error?.errorCode
        XCTAssertNil(tabErrorCode2)
    }

    @MainActor
    func testPhishingDetectedViaHTTPRedirectChain_tabIsMarkedPhishing() async throws {
        try await loadUrl("http://bad.third-party.site/security/badware/phishing-redirect/")
        try await waitForTabToFinishLoading()
        let tabErrorCode = tabViewModel.tab.error?.errorCode
        XCTAssertEqual(tabErrorCode, PhishingDetectionError.detected.errorCode)
    }

    @MainActor
    func testPhishingDetectedRepeatedRedirectChains_tabIsMarkedPhishing() async throws {
        let urls = [
            "http://bad.third-party.site/security/badware/phishing-js-redirector-helper.html",
            "http://bad.third-party.site/security/badware/phishing-js-redirector.html",
            "http://bad.third-party.site/security/badware/phishing-meta-redirect.html",
            "http://bad.third-party.site/security/badware/phishing-redirect/",
            "http://bad.third-party.site/security/badware/phishing-redirect/302",
            "http://bad.third-party.site/security/badware/phishing-redirect/js",
            "http://bad.third-party.site/security/badware/phishing-redirect/meta",
            "http://bad.third-party.site/security/badware/phishing-redirect/meta2"
        ]

        for url in urls {
            try await loadUrl(url)
            try await waitForTabToFinishLoading()
            let tabErrorCode = tabViewModel.tab.error?.errorCode
            XCTAssertEqual(tabErrorCode, PhishingDetectionError.detected.errorCode)
        }
    }

    // MARK: - Helper Methods

    @MainActor
    private func loadUrl(_ urlString: String) async throws {
        guard let url = URL(string: urlString) else { return }
        _ = await tabViewModel.tab.setUrl(url, source: .link)?.result
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
