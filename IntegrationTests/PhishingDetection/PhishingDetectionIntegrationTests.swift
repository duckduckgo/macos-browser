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
        // disable GPC redirects
        WebTrackingProtectionPreferences.shared.isGPCEnabled = false
        PhishingDetectionPreferences.shared.isEnabled = true

        window = WindowsManager.openNewWindow(with: .none)!
    }

    @MainActor
    override func tearDown() async throws {
        window.close()
        window = nil

        WebTrackingProtectionPreferences.shared.isGPCEnabled = true
    }

    // MARK: - Tests
    @MainActor
    func testWhenPhishingNotDetected_tabIsNotMarkedPhishing() async throws {
        let tabViewModel = self.tabViewModel
        let tab = tabViewModel.tab

        // load the test page
        let url = URL(string: "http://privacy-test-pages.site/")!
        _=await tab.setUrl(url, source: .link)?.result
        XCTAssertFalse(tab.phishingState.isShowingPhishingError)
    }

    @MainActor
    func testWhenPhishingDetected_tabIsMarkedPhishing() async throws {
        let tabViewModel = self.tabViewModel
        let tab = tabViewModel.tab

        // load fake phishing test page
        let url = URL(string: "http://privacy-test-pages.site/security/badware/phishing.html")!
        _=await tab.setUrl(url, source: .link)?.result
        XCTAssertTrue(tab.phishingState.isShowingPhishingError)
        XCTAssertFalse(tab.phishingState.didBypassError)
    }

    @MainActor
    func testWhenPhishingDetectedThenNotDetected_tabIsNotMarkedPhishing() async throws {
        let tabViewModel = self.tabViewModel
        let tab = tabViewModel.tab

        // load fake phishing test page
        let url = URL(string: "http://privacy-test-pages.site/security/badware/phishing.html")!
        _=await tab.setUrl(url, source: .link)?.result
        XCTAssertTrue(tab.phishingState.isShowingPhishingError)
        try await Task.sleep(nanoseconds: 1_000_000_000)
        let url2 = URL(string: "http://broken.third-party.site/")!
        _=await tab.setUrl(url2, source: .link)?.result
        try await Task.sleep(nanoseconds: 1_000_000_000)
        if let privacyInfo = tab.privacyInfo {
            XCTAssertFalse(privacyInfo.isPhishing)
            XCTAssertFalse(tab.phishingState.isShowingPhishingError)
            XCTAssertFalse(tab.phishingState.didBypassError)
        }
    }

    @MainActor
    func testWhenPhishingWarningClickedThrough_tabIsMarkedAsBypassed() async throws {
        let tabViewModel = self.tabViewModel
        let tab = tabViewModel.tab

        // load fake phishing test page - errorPageType = Phishing
        let url = URL(string: "http://privacy-test-pages.site/security/badware/phishing.html")!
        _=await tab.setUrl(url, source: .link)?.result
        XCTAssertTrue(tab.phishingState.isShowingPhishingError)
        while tab.isLoading {
            try await Task.sleep(nanoseconds: 1_000_000_000)
        }
        // now visit site
        let showAdvancedScript: String = "document.getElementsByClassName('Warning_advanced')[0].click()"
        try? await tab.webView.evaluateJavaScript(showAdvancedScript) as Void?
        let clickThroughScript: String = "document.getElementsByClassName('AdvancedInfo_visitSite')[0].click()"
        try? await tab.webView.evaluateJavaScript(clickThroughScript) as Void?
        try await Task.sleep(nanoseconds: 1_000_000_000)
        if let privacyInfo = tab.privacyInfo {
            XCTAssertTrue(privacyInfo.isPhishing)
            XCTAssertFalse(tab.phishingState.isShowingPhishingError)
            XCTAssertTrue(tab.phishingState.didBypassError)
        }
    }

    @MainActor
    func testWhenPhishingDetectedThenDDGLoaded_tabIsNotMarkedPhishing() async throws {
        let tabViewModel = self.tabViewModel
        let tab = tabViewModel.tab

        // load fake phishing test page
        let url = URL(string: "http://privacy-test-pages.site/security/badware/phishing.html")!
        _=await tab.setUrl(url, source: .link)?.result
        XCTAssertTrue(tab.phishingState.isShowingPhishingError)
        try await Task.sleep(nanoseconds: 1_000_000_000)
        // we have special exceptions for DDG URLs, which previously caused a bug where phishing sites that quickly navigated to DDG caused a broken phishingState
        let url2 = URL(string: "http://duckduckgo.com/")!
        _=await tab.setUrl(url2, source: .link)?.result
        try await Task.sleep(nanoseconds: 1_000_000_000)
        if let privacyInfo = tab.privacyInfo {
            XCTAssertFalse(privacyInfo.isPhishing)
            XCTAssertFalse(tab.phishingState.isShowingPhishingError)
            XCTAssertFalse(tab.phishingState.didBypassError)
        }
    }

    @MainActor
    func testWhenPhishingDetectedInIframe_tabIsMarkedPhishing() async throws {
        let tabViewModel = self.tabViewModel
        let tab = tabViewModel.tab

        // load fake phishing test page
        let url = URL(string: "http://bad.third-party.site/security/badware/phishing-iframe-loader.html")!
        _=await tab.setUrl(url, source: .link)?.result
        XCTAssertTrue(tab.phishingState.isShowingPhishingError)
        XCTAssertFalse(tab.phishingState.didBypassError)
    }

    @MainActor
    func testWhenPhishingDetectedViaRedirectChain_tabIsMarkedPhishing() async throws {
        let tabViewModel = self.tabViewModel
        let tab = tabViewModel.tab

        // load fake phishing test page with redirector
        let url = URL(string: "http://bad.third-party.site/security/badware/phishing-js-redirector-helper.html")!
        _=await tab.setUrl(url, source: .link)?.result
        XCTAssertTrue(tab.phishingState.isShowingPhishingError)
        XCTAssertFalse(tab.phishingState.didBypassError)
    }
}
