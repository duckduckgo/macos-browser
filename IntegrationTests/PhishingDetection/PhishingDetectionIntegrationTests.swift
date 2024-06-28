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
        var errorPage = tab.specialErrorPage as! SpecialErrorPageTabExtension

        // load the test page
        let url = URL(string: "http://privacy-test-pages.site/")!
        _=await tab.setUrl(url, source: .link)?.result
        XCTAssertFalse(tab.phishingState.tabIsPhishing)
    }

    @MainActor
    func testWhenPhishingDetected_tabIsMarkedPhishing() async throws {
        var cancellables = Set<AnyCancellable>()
        let tabViewModel = self.tabViewModel
        let tab = tabViewModel.tab
        var errorPage = try XCTUnwrap(tab.specialErrorPage as? SpecialErrorPageTabExtension)

        // load fake phishing test page - errorPageType = Phishing
        let url = URL(string: "http://privacy-test-pages.site/security/badware/phishing.html")!
        _=await tab.setUrl(url, source: .link)?.result
        XCTAssertTrue(tab.phishingState.tabIsPhishing)
    }

    @MainActor
    func testWhenPhishingDetectedThenNotDetected_tabIsNotMarkedPhishing() async throws {
        var cancellables = Set<AnyCancellable>()
        let tabViewModel = self.tabViewModel
        let tab = tabViewModel.tab
        var errorPage = try XCTUnwrap(tab.specialErrorPage as? SpecialErrorPageTabExtension)

        // load fake phishing test page - errorPageType = Phishing
        let url = URL(string: "http://privacy-test-pages.site/security/badware/phishing.html")!
        _=await tab.setUrl(url, source: .link)?.result
        XCTAssertTrue(tab.phishingState.tabIsPhishing)
        let url2 = URL(string: "http://privacy-test-pages.site/")!
        _=await tab.setUrl(url2, source: .link)?.result
        XCTAssertFalse(tab.phishingState.tabIsPhishing)
    }
}
