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
import os.log

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

    @MainActor
    override func setUp() {
        // disable GPC redirects
        WebTrackingProtectionPreferences.shared.isGPCEnabled = false

        window = WindowsManager.openNewWindow(with: Tab(content: .none))
    }

    @MainActor
    override func tearDown() async throws {
        window.close()
        window = nil

        WebTrackingProtectionPreferences.shared.isGPCEnabled = true
    }

    // MARK: - Tests

    @MainActor
    func testWhenAutoconsentEnabled_cookieConsentManaged() async throws {
        // enable the feature
        CookiePopupProtectionPreferences.shared.isAutoconsentEnabled = true
        let url = URL(string: "http://privacy-test-pages.site/features/autoconsent/")!
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
            .timeout(10)
            .first()
            .promise()

        _=await tab.setUrl(url, source: .link)?.result

        let cookieConsentManaged = try await cookieConsentManagedPromise.value
        XCTAssertTrue(cookieConsentManaged)
    }

    @MainActor
    func testCosmeticRule_whenFakeCookieBannerIsDisplayed_bannerIsHidden() async throws {
        // enable the feature
        CookiePopupProtectionPreferences.shared.isAutoconsentEnabled = true
        let url = URL(string: "http://privacy-test-pages.site/features/autoconsent/banner.html")!
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

        _=await tab.setUrl(url, source: .link)?.result

        do {
            let cookieConsentManaged = try await cookieConsentManagedPromise.value
            XCTAssertTrue(cookieConsentManaged == true)
        } catch {
            struct ErrorWithHTML: Error, LocalizedError, CustomDebugStringConvertible {
                let originalError: Error
                let html: String

                var errorDescription: String? {
                    (originalError as CustomDebugStringConvertible).debugDescription + "\nHTML:\n\(html)"
                }
                var debugDescription: String {
                    errorDescription!
                }
            }
            let html = try await tab.webView.evaluateJavaScript("document.documentElement.outerHTML") as String?

            if let html {
                throw ErrorWithHTML(originalError: error, html: html)
            } else {
                throw error
            }
        }

        let isBannerHidden = try await tab.webView.evaluateJavaScript("window.getComputedStyle(banner).display === 'none'") as Bool?
        XCTAssertTrue(isBannerHidden == true)
    }

    @MainActor
    func testCosmeticRule_whenFakeCookieBannerIsDisplayedAndScriptsAreReloaded_bannerIsHidden() async throws {
        // enable the feature
        CookiePopupProtectionPreferences.shared.isAutoconsentEnabled = true
        let url = URL(string: "http://privacy-test-pages.site/features/autoconsent/banner.html")!
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

        Logger.general.debug("starting navigation to http://privacy-test-pages.site/features/autoconsent/banner.html")
        let navigation = tab.setUrl(url, source: .link)

        navigation?.appendResponder(navigationResponse: { response in
            Logger.general.debug("navigationResponse: \(String(describing: response))")

            // cause UserScripts reload (ContentBlockingUpdating)
            WebTrackingProtectionPreferences.shared.isGPCEnabled = true
            WebTrackingProtectionPreferences.shared.isGPCEnabled = false

            return .allow
        })
        _=await navigation?.result

        Logger.general.debug("navigation done")
        let cookieConsentManaged = try await cookieConsentManagedPromise.value
        XCTAssertTrue(cookieConsentManaged == true)

        let isBannerHidden = try await tab.webView.evaluateJavaScript("window.getComputedStyle(banner).display === 'none'") as Bool?
        XCTAssertTrue(isBannerHidden == true)
    }

    @MainActor
    func testFilterlistRule_whenFakeCookieBannerIsDisplayed_bannerIsHidden() async throws {
        // enable the feature
        CookiePopupProtectionPreferences.shared.isAutoconsentEnabled = true
        let url = URL(string: "http://privacy-test-pages.site/features/autoconsent/filterlist.html")!
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

        _=await tab.setUrl(url, source: .link)?.result

        do {
            let cookieConsentManaged = try await cookieConsentManagedPromise.value
            XCTAssertTrue(cookieConsentManaged == true)
        } catch {
            struct ErrorWithHTML: Error, LocalizedError, CustomDebugStringConvertible {
                let originalError: Error
                let html: String

                var errorDescription: String? {
                    (originalError as CustomDebugStringConvertible).debugDescription + "\nHTML:\n\(html)"
                }
                var debugDescription: String {
                    errorDescription!
                }
            }
            let html = try await tab.webView.evaluateJavaScript("document.documentElement.outerHTML") as String?

            if let html {
                throw ErrorWithHTML(originalError: error, html: html)
            } else {
                throw error
            }
        }

        let isBannerHidden = try await tab.webView.evaluateJavaScript("window.getComputedStyle(banner).opacity === '0'") as Bool?
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
