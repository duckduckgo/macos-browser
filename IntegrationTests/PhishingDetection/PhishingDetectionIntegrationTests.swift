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

@testable import DuckDuckGo_Privacy_Browser

@available(macOS 12.0, *)
class PhishingDetectionIntegrationTests: XCTestCase {

    var window: NSWindow!
    var tabViewModel: TabViewModel {
        (window.contentViewController as! MainViewController).browserTabViewController.tabViewModel!
    }

    @MainActor
    override func setUp() {
        super.setUp()
        WebTrackingProtectionPreferences.shared.isGPCEnabled = false
        PhishingDetectionPreferences.shared.isEnabled = true
        window = WindowsManager.openNewWindow(with: .none)!
    }

    @MainActor
    override func tearDown() async throws {
        window.close()
        window = nil
        WebTrackingProtectionPreferences.shared.isGPCEnabled = true
        try await super.tearDown()
    }

    // MARK: - Tests

    @MainActor
    func testPhishingNotDetected_tabIsNotMarkedPhishing() async throws {
        try await loadUrl("http://privacy-test-pages.site/")
        XCTAssertFalse(tabViewModel.tab.url?.isPhishingErrorPage ?? true)
    }

    @MainActor
    func testPhishingDetected_tabIsMarkedPhishing() async throws {
        try await loadUrl("http://privacy-test-pages.site/security/badware/phishing.html")
        XCTAssertTrue(tabViewModel.tab.url?.isPhishingErrorPage ?? false)
    }

    @MainActor
    func testPhishingDetectedThenNotDetected_tabIsNotMarkedPhishing() async throws {
        try await loadUrl("http://privacy-test-pages.site/security/badware/phishing.html")
        XCTAssertTrue(tabViewModel.tab.url?.isPhishingErrorPage ?? false)

        try await Task.sleep(nanoseconds: 1_000_000_000)
        try await loadUrl("http://broken.third-party.site/")
        try await Task.sleep(nanoseconds: 1_000_000_000)

        XCTAssertFalse(tabViewModel.tab.privacyInfo?.isPhishing ?? true)
        XCTAssertFalse(tabViewModel.tab.url?.isPhishingErrorPage ?? true)
    }

    @MainActor
    func testPhishingWarningClickedThrough_privacyInfoIsUpdated() async throws {
        try await loadUrl("http://privacy-test-pages.site/security/badware/phishing.html")
        XCTAssertTrue(tabViewModel.tab.url?.isPhishingErrorPage ?? false)

        while tabViewModel.tab.isLoading {
            try await Task.sleep(nanoseconds: 1_000_000_000)
        }

        try await clickThroughPhishingWarning()
        XCTAssertTrue(tabViewModel.tab.privacyInfo?.isPhishing ?? false)
        XCTAssertFalse(tabViewModel.tab.url?.isPhishingErrorPage ?? true)
    }

    @MainActor
    func testPhishingDetectedThenDDGLoaded_tabIsNotMarkedPhishing() async throws {
        try await loadUrl("http://privacy-test-pages.site/security/badware/phishing.html")
        XCTAssertTrue(tabViewModel.tab.url?.isPhishingErrorPage ?? false)

        try await Task.sleep(nanoseconds: 1_000_000_000)
        try await loadUrl("http://duckduckgo.com/")
        try await Task.sleep(nanoseconds: 1_000_000_000)

        XCTAssertFalse(tabViewModel.tab.privacyInfo?.isPhishing ?? true)
        XCTAssertFalse(tabViewModel.tab.url?.isPhishingErrorPage ?? true)
    }

    @MainActor
    func testPhishingDetectedViaJSRedirectChain_tabIsMarkedPhishing() async throws {
        try await loadUrl("http://bad.third-party.site/security/badware/phishing-js-redirector-helper.html")
        XCTAssertTrue(tabViewModel.tab.url?.isPhishingErrorPage ?? false)
        try await Task.sleep(nanoseconds: 1_000_000_000)
        let errorPageHTMLDidRender = await errorPageHTMLRendered(inTab: tabViewModel.tab)
        XCTAssertTrue(errorPageHTMLDidRender)
    }

    @MainActor
    func testPhishingDetectedViaHTTPRedirectChain_tabIsMarkedPhishing() async throws {
        try await loadUrl("http://bad.third-party.site/security/badware/phishing-redirect/")
        XCTAssertTrue(tabViewModel.tab.url?.isPhishingErrorPage ?? false)
        try await Task.sleep(nanoseconds: 1_000_000_000)
        let errorPageHTMLDidRender = await errorPageHTMLRendered(inTab: tabViewModel.tab)
        XCTAssertTrue(errorPageHTMLDidRender)
    }

    @MainActor
    func testPhishingDetectedInIframe_tabIsMarkedPhishing() async throws {
        try await loadUrl("http://bad.third-party.site/security/badware/phishing-iframe-loader.html")
        try await Task.sleep(nanoseconds: 1_000_000_000)
        let errorPageHTMLDidRender = await errorPageHTMLRendered(inTab: tabViewModel.tab)
        XCTAssertTrue(errorPageHTMLDidRender)
    }

    @MainActor
    func testPhishingDetectedRepeatedRedirectChains_tabIsMarkedPhishing() async throws {
        for _ in 0..<10 {
            try await loadUrl("http://bad.third-party.site/security/badware/phishing-js-redirector-helper.html")
            XCTAssertTrue(tabViewModel.tab.url?.isPhishingErrorPage ?? false)
            try await Task.sleep(nanoseconds: 1_000_000_000)
            let errorPageHTMLDidRender = await errorPageHTMLRendered(inTab: tabViewModel.tab)
            XCTAssertTrue(errorPageHTMLDidRender)
        }
    }

    // MARK: - Helper Methods
    @MainActor
    private func loadUrl(_ urlString: String) async throws {
        let url = URL(string: urlString)!
        _ = await tabViewModel.tab.setUrl(url, source: .link)?.result
    }

    @MainActor
    func errorPageHTMLRendered(inTab: Tab) async -> Bool {
        return await withCheckedContinuation { continuation in
            inTab.webView.evaluateJavaScript("document.documentElement.outerHTML") { (html, error) in
                var containsPhishing = false
                if let htmlString = html as? String {
                    containsPhishing = htmlString.contains("Error Page")
                }
                continuation.resume(returning: containsPhishing)
            }
        }
    }

    @MainActor
    private func clickThroughPhishingWarning() async throws {
        let showAdvancedScript = "document.getElementsByClassName('Warning_advanced')[0].click()"
        try? await tabViewModel.tab.webView.evaluateJavaScript(showAdvancedScript) as Void?

        let clickThroughScript = "document.getElementsByClassName('AdvancedInfo_visitSite')[0].click()"
        try? await tabViewModel.tab.webView.evaluateJavaScript(clickThroughScript) as Void?

        try await Task.sleep(nanoseconds: 1_000_000_000)
    }
}
