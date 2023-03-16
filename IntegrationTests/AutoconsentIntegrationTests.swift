//
//  AutoconsentIntegrationTests.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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
import PrivacyDashboard
import XCTest
@testable import DuckDuckGo_Privacy_Browser

@available(macOS 12.0, *)
class AutoconsentIntegrationTests: XCTestCase {

    var window: NSWindow!

    var mainViewController: MainViewController {
        (window.contentViewController as! MainViewController)
    }

    var tabViewModel: TabViewModel {
        mainViewController.browserTabViewController.tabViewModel!
    }

    override func setUp() {
        // disable GPC redirects
        PrivacySecurityPreferences.shared.gpcEnabled = false

        window = WindowsManager.openNewWindow(with: .none)!
    }

    override func tearDown() {
        window.close()
        window = nil

        PrivacySecurityPreferences.shared.gpcEnabled = true
    }

    // MARK: - Tests

    @MainActor
    func testAutoconsent() async throws {
        PrivacySecurityPreferences.shared.autoconsentEnabled = true
        let url = URL(string: "http://privacy-test-pages.glitch.me/features/autoconsent/")!

        let tabViewModel = self.tabViewModel
        let tab = tabViewModel.tab

        _=await tab.setUrl(url, userEntered: false)?.value?.result

        // expect connectionUpgradedTo to be published
        let cookieConsentManagedPromise = tab.privacyInfoPublisher
            .compactMap {
                $0?.$cookieConsentManaged
            }
            .switchToLatest()
            .filter {
                $0?.isConsentManaged == true
            }
            .map {
                $0!.isConsentManaged
            }
            .timeout(5)
            .first()
            .promise()

        let cookieConsentManaged = try await cookieConsentManagedPromise.value
        XCTAssertTrue(cookieConsentManaged)
    }

    @MainActor
    func testWhenAutoconsentDisabled_promptIsDisplayed() async throws {
        PrivacySecurityPreferences.shared.autoconsentEnabled = nil
        let url = URL(string: "http://privacy-test-pages.glitch.me/features/autoconsent/")!

        let tabViewModel = self.tabViewModel
        let tab = tabViewModel.tab

        _=await tab.setUrl(url, userEntered: false)?.value?.result

        // expect cookieConsent request to be published
        let cookieConsentPromptRequestPromise = tab.cookieConsentPromptRequestPublisher
            .compactMap { $0 != nil ? true : nil }
            .timeout(5)
            .first()
            .promise()

        let cookieConsentPromptRequestPublished = try await cookieConsentPromptRequestPromise.value
        XCTAssertTrue(cookieConsentPromptRequestPublished)
        XCTAssertTrue(mainViewController.view.window!.childWindows?.first?.contentViewController is CookieConsentUserPermissionViewController)

        // expect cookieConsent popover to be hidden when opening a new tab
        mainViewController.browserTabViewController.openNewTab(with: .none, selected: true)
        XCTAssertFalse(mainViewController.view.window!.childWindows?.first?.contentViewController is CookieConsentUserPermissionViewController)

        // switch back: popover should be reopen
        mainViewController.tabCollectionViewModel.select(at: .unpinned(0))
        XCTAssertTrue(mainViewController.view.window!.childWindows?.first?.contentViewController is CookieConsentUserPermissionViewController)
    }

}

private extension CookieConsentInfo {

    var isConsentManaged: Bool {
        try! (JSONSerialization.jsonObject(with: JSONEncoder().encode(self)) as! [String: Any])["consentManaged"] as! Bool
    }

}
