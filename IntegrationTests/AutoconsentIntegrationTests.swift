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
    func testWhenAutoconsentEnabled_cookieConsentManaged() async throws {
        // enable the feature
        PrivacySecurityPreferences.shared.autoconsentEnabled = true
        let url = URL(string: "http://privacy-test-pages.glitch.me/features/autoconsent/")!

        let tab = self.tabViewModel.tab

        // expect cookieConsentManaged to be published
        let cookieConsentManagedPromise = tab.privacyInfoPublisher
            .compactMap {
                $0?.$cookieConsentManaged
            }
            .switchToLatest()
            .compactMap {
                $0?.isConsentManaged == true ? true : nil
            }
            .timeout(5)
            .first()
            .promise()

        _=await tab.setUrl(url, userEntered: nil)?.value?.result

        let cookieConsentManaged = try await cookieConsentManagedPromise.value
        XCTAssertTrue(cookieConsentManaged)
    }

    @MainActor
    func testWhenAutoconsentDisabled_promptIsDisplayed() async throws {
        // reset the feature setting
        PrivacySecurityPreferences.shared.autoconsentEnabled = nil
        let url = URL(string: "http://privacy-test-pages.glitch.me/features/autoconsent/")!

        let tab = self.tabViewModel.tab

        _=await tab.setUrl(url, userEntered: nil)?.value?.result

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
        mainViewController.browserTabViewController.openNewTab(with: .none)
        XCTAssertFalse(mainViewController.view.window!.childWindows?.first?.contentViewController is CookieConsentUserPermissionViewController)

        // switch back: popover should be reopen
        mainViewController.tabCollectionViewModel.select(at: .unpinned(0))
        XCTAssertTrue(mainViewController.view.window!.childWindows?.first?.contentViewController is CookieConsentUserPermissionViewController)
    }

    @MainActor
    func testCosmeticRule_whenFakeCookieBannerIsDisplayed_bannerIsHidden() async throws {
        // enable the feature
        PrivacySecurityPreferences.shared.autoconsentEnabled = true
        let url = URL(string: "http://privacy-test-pages.glitch.me/features/autoconsent/banner.html")!

        let tab = self.tabViewModel.tab
        // expect `cosmetic` to be published
        let cookieConsentManagedPromise = tab.privacyInfoPublisher
            .compactMap {
                return $0?.$cookieConsentManaged
            }
            .switchToLatest()
            .compactMap {
                return $0?.isCosmeticRuleApplied == true ? true : nil
            }
            .receive(on: DispatchQueue.main)
            .timeout(10)
            .first()
            .promise()

        _=await tab.setUrl(url, userEntered: nil)?.value?.result

        let cookieConsentManaged = try await cookieConsentManagedPromise.value
        XCTAssertTrue(cookieConsentManaged == true)

        let isBannerHidden = try await tab.webView.evaluateJavaScript("window.getComputedStyle(banner).display === 'none'") as? Bool
        XCTAssertTrue(isBannerHidden == true)
    }

    @MainActor
    func testCosmeticRule_whenFakeCookieBannerIsDisplayedAndScriptsAreReloaded_bannerIsHidden() async throws {
        // enable the feature
        PrivacySecurityPreferences.shared.autoconsentEnabled = true
        let url = URL(string: "http://privacy-test-pages.glitch.me/features/autoconsent/banner.html")!

        let tab = self.tabViewModel.tab
        // expect `cosmetic` to be published
        let cookieConsentManagedPromise = tab.privacyInfoPublisher
            .compactMap {
                return $0?.$cookieConsentManaged
            }
            .switchToLatest()
            .compactMap {
                return $0?.isCosmeticRuleApplied == true ? true : nil
            }
            .receive(on: DispatchQueue.main)
            .timeout(5)
            .first()
            .promise()

        os_log("starting navigation to http://privacy-test-pages.glitch.me/features/autoconsent/banner.html")
        let navigation = await tab.setUrl(url, userEntered: nil)?.value

        navigation?.appendResponder(navigationResponse: { response in
            os_log("navigationResponse: %s", "\(String(describing: response))")

            // cause UserScripts reload (ContentBlockingUpdating)
            PrivacySecurityPreferences.shared.gpcEnabled = true
            PrivacySecurityPreferences.shared.gpcEnabled = false

            return .allow
        })
        _=await navigation?.result

        os_log("navigation done")
        let cookieConsentManaged = try await cookieConsentManagedPromise.value
        XCTAssertTrue(cookieConsentManaged == true)

        let isBannerHidden = try await tab.webView.evaluateJavaScript("window.getComputedStyle(banner).display === 'none'") as? Bool
        XCTAssertTrue(isBannerHidden == true)
    }

}

private extension CookieConsentInfo {

    var isConsentManaged: Bool {
        Mirror(reflecting: self).children.first(where: { $0.label == "consentManaged" })?.value as! Bool
    }

    var isCosmeticRuleApplied: Bool {
        (Mirror(reflecting: self).children.first(where: { $0.label == "cosmetic" })?.value as? Bool) ?? false
    }

}
