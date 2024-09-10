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
    func testWhenPhishingDetected_tabIsMarkedPhishing() async throws {
        try await testPhishingDetection(urlString: "http://privacy-test-pages.site/security/badware/phishing.html", expectedIsPhishing: true)
    }

    @MainActor
    func testWhenPhishingDetectedviaHTTPRedirect_tabIsMarkedPhishing() async throws {
        try await testPhishingDetection(urlString: "http://privacy-test-pages.site/security/badware/phishing-redirect/", expectedIsPhishing: true)
    }

    @MainActor
    func testWhenPhishingDetectedviaJSRedirect_tabIsMarkedPhishing() async throws {
        try await testPhishingDetection(urlString: "http://privacy-test-pages.site/security/badware/phishing-js-redirector.html", expectedIsPhishing: true)
    }

    @MainActor
    func testWhenPhishingDetectedviaIframe_tabIsMarkedPhishing() async throws {
        try await testPhishingDetection(urlString: "http://bad.third-party.site/security/badware/phishing-iframe-loader.html", expectedIsPhishing: true)
    }

    @MainActor
    func testFeatureDisabledAndPhishingDetection_tabIsNotMarkedPhishing() async throws {
        PhishingDetectionPreferences.shared.isEnabled = false
        try await testPhishingDetection(urlString: "http://privacy-test-pages.site/security/badware/phishing.html", expectedIsPhishing: false, expectedErrorCode: nil)
    }

    @MainActor
    func testPhishingDetectedThenNotDetected_tabIsNotMarkedPhishing() async throws {
        let initialUrl = "http://privacy-test-pages.site/security/badware/phishing.html"
        let subsequentUrl = "https://privacy-test-pages.site"

        try await testPhishingDetection(urlString: initialUrl, expectedIsPhishing: true)
        try await testPhishingDetection(urlString: subsequentUrl, expectedIsPhishing: false)
    }

    @MainActor
    func testPhishingDetectedThenDDGLoaded_tabIsNotMarkedPhishing() async throws {
        let initialUrl = "http://privacy-test-pages.site/security/badware/phishing.html"
        let subsequentUrl = "https://duckduckgo.com"

        try await testPhishingDetection(urlString: initialUrl, expectedIsPhishing: true)
        try await testPhishingDetection(urlString: subsequentUrl, expectedIsPhishing: false)
    }

    // MARK: - Helper Methods

    @MainActor
    private func testPhishingDetection(urlString: String, expectedIsPhishing: Bool, expectedErrorCode: Int? = PhishingDetectionError.detected.errorCode) async throws {
        let isPhishingPromise = tab.privacyInfoPublisher
            .compactMap { $0?.$isPhishing }
            .map { _ in expectedIsPhishing }
            .timeout(10)
            .first()
            .promise()
        let navigationFailedPromise = tab.$error.compactMap { $0 }.timeout(5).first().promise()

        loadUrl(urlString)

        let isPhishing = try await isPhishingPromise.value
        XCTAssertEqual(isPhishing, expectedIsPhishing)
        if expectedIsPhishing {
            _ = try await navigationFailedPromise.value
            XCTAssertEqual(tab.error!.errorCode, PhishingDetectionError.detected.errorCode)
        }

    }

    @MainActor
    private func loadUrl(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        tab.navigateTo(url: url)
    }
}

class MockFeatureFlagger: FeatureFlagger {
    func isFeatureOn<F>(forProvider: F) -> Bool where F: BrowserServicesKit.FeatureFlagSourceProviding {
        return true
    }
}
