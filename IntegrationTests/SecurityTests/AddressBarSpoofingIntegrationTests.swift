//
//  AddressBarSpoofingIntegrationTests.swift
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
import Navigation
import os.log
import XCTest
@testable import DuckDuckGo_Privacy_Browser

@available(macOS 12.0, *)
class AddressBarSpoofingIntegrationTests: XCTestCase {

    var window: NSWindow!

    var mainViewController: MainViewController {
        (window.contentViewController as! MainViewController)
    }

    var tabViewModel: TabViewModel {
        mainViewController.browserTabViewController.tabViewModel!
    }

    @MainActor
    override func setUp() async throws {

    }

    override func tearDown() {
        window?.close()
        window = nil

        PrivacySecurityPreferences.shared.gpcEnabled = true
    }

    // MARK: - Tests

    @MainActor
    func testUrlBarSpoofingWithLongLoadingNavigations() async throws {
        let tab = Tab(content: .none)
        window = WindowsManager.openNewWindow(with: tab)!

        // run
        let url = URL(string: "https://privacy-test-pages.site/security/address-bar-spoofing/spoof-js-page-rewrite.html")!
        PrivacySecurityPreferences.shared.gpcEnabled = false
        _=try await tab.setUrl(url, userEntered: nil)?.result.get()
        _=try await tab.webView.evaluateJavaScript("(function() { run(); return true; })()")

        // wait
        try await Task.sleep(nanoseconds: UInt64(100 * Double(NSEC_PER_MSEC))) // wait for isLoading to be true
        while tab.isLoading {
            try await Task.sleep(nanoseconds: UInt64(100 * Double(NSEC_PER_MSEC)))
        }

        // address bar should not be updated this early
        let tabViewModel = (window.contentViewController as! MainViewController).browserTabViewController.tabViewModel!
        XCTAssertNotEqual(tabViewModel.addressBarString, "https://duckduckgo.com:8443/")
    }

    @MainActor
    func testUrlBarSpoofingWithUnsupportedApplicationScheme() async throws {
        let tab = Tab(content: .none)
        window = WindowsManager.openNewWindow(with: tab)!

        let url = URL(string: "https://privacy-test-pages.site/security/address-bar-spoofing/spoof-application-scheme.html")!
        PrivacySecurityPreferences.shared.gpcEnabled = false
        _=try await tab.setUrl(url, userEntered: nil)?.result.get()

        // run
        _=try await tab.webView.evaluateJavaScript("(function() { document.getElementById('run').click(); return true; })()")

        // wait
        try await Task.sleep(nanoseconds: UInt64(100 * Double(NSEC_PER_MSEC))) // wait for isLoading to be true
        let tabViewModel = (window.contentViewController as! MainViewController).browserTabViewController.tabViewModel!
        while tabViewModel.tab.isLoading {
            try await Task.sleep(nanoseconds: UInt64(100 * Double(NSEC_PER_MSEC)))
        }

        // the exploit is unreliable, so we also accept address bar being empty string
        let spoofedContent = try await tabViewModel.tab.webView.find("Not DDG.")
        let addressBarUpdatedAndContentNotSpoofed = tabViewModel.addressBarString == "https://duckduckgo.com/" && !spoofedContent.matchFound
        let addressBarEmptyWithSpoofedContent = tabViewModel.addressBarString == "" && spoofedContent.matchFound
        XCTAssertTrue(addressBarUpdatedAndContentNotSpoofed || addressBarEmptyWithSpoofedContent)
    }

    @MainActor
    func testUrlBarSpoofingWithSpoofAboutBlankRewrite() async throws {
        let tab = Tab(content: .none)
        window = WindowsManager.openNewWindow(with: tab)!

        let url = URL(string: "https://privacy-test-pages.site/security/address-bar-spoofing/spoof-about-blank-rewrite.html")!
        PrivacySecurityPreferences.shared.gpcEnabled = false
        _ = try await tab.setUrl(url, userEntered: nil)?.result.get()

        // run
        _ = try await tab.webView.evaluateJavaScript("(function() { document.getElementById('run').click(); return true; })()")

        // wait
        let tabViewModel = (window.contentViewController as! MainViewController).browserTabViewController.tabViewModel!
        while tabViewModel.tab.isLoading {
            try await Task.sleep(nanoseconds: UInt64(100 * Double(NSEC_PER_MSEC)))
        }

        // assert
        let spoofedContent = try await tabViewModel.tab.webView.find("Not DDG.")
        let addressBarNotSpoofed = tabViewModel.addressBarString == "https://privacy-test-pages.site/security/address-bar-spoofing/spoof-about-blank-rewrite.html"
        XCTAssertTrue(spoofedContent.matchFound && addressBarNotSpoofed)
    }

    @MainActor
    func testUrlBarSpoofingWithBasicAuth2028() async throws {
        let tab = Tab(content: .none)
        window = WindowsManager.openNewWindow(with: tab)!

        let url = URL(string: "https://privacy-test-pages.site/security/address-bar-spoofing/spoof-basicauth-2028.html")!
        PrivacySecurityPreferences.shared.gpcEnabled = false
        _ = try await tab.setUrl(url, userEntered: nil)?.result.get()

        // run
        _=try await tab.webView.evaluateJavaScript("(function() { run(); return true; })()")

        // wait
        try await Task.sleep(nanoseconds: UInt64(100 * Double(NSEC_PER_MSEC))) // wait for isLoading to be true
        let tabViewModel = (window.contentViewController as! MainViewController).browserTabViewController.tabViewModel!
        while tab.isLoading {
            try await Task.sleep(nanoseconds: UInt64(100 * Double(NSEC_PER_MSEC)))
        }

        // assert
        let basicAuthStrippedFromAddressBar = tabViewModel.addressBarString == "https://example.com/"
        XCTAssertTrue(basicAuthStrippedFromAddressBar)
    }

    @MainActor
    func testUrlBarSpoofingWithBasicAuthWhitespace() async throws {
        let tab = Tab(content: .none)
        window = WindowsManager.openNewWindow(with: tab)!

        let url = URL(string: "https://privacy-test-pages.site/security/address-bar-spoofing/spoof-basicauth-whitespace.html")!
        PrivacySecurityPreferences.shared.gpcEnabled = false
        _ = try await tab.setUrl(url, userEntered: nil)?.result.get()

        // run
        _ = try await tab.webView.evaluateJavaScript("(function() { document.getElementById('run').click(); return true; })()")

        // wait
        try await Task.sleep(nanoseconds: UInt64(100 * Double(NSEC_PER_MSEC))) // wait for isLoading to be true
        let tabViewModel = (window.contentViewController as! MainViewController).browserTabViewController.tabViewModel!
        while tabViewModel.tab.isLoading {
            try await Task.sleep(nanoseconds: UInt64(100 * Double(NSEC_PER_MSEC)))
        }

        // assert
        let basicAuthStrippedFromAddressBar = tabViewModel.addressBarString == "https://example.com/"
        XCTAssertTrue(basicAuthStrippedFromAddressBar)
    }

    @MainActor
    func testUrlBarSpoofingWithBasicAuth2029() async throws {
        let tab = Tab(content: .none)
        window = WindowsManager.openNewWindow(with: tab)!

        let url = URL(string: "https://privacy-test-pages.site/security/address-bar-spoofing/spoof-basicauth-2029.html")!
        PrivacySecurityPreferences.shared.gpcEnabled = false
        _ = try await tab.setUrl(url, userEntered: nil)?.result.get()

        // run
        _ = try await tab.webView.evaluateJavaScript("(function() { document.getElementById('run').click(); return true; })()")

        // wait
        try await Task.sleep(nanoseconds: UInt64(100 * Double(NSEC_PER_MSEC))) // wait for isLoading to be true
        let tabViewModel = (window.contentViewController as! MainViewController).browserTabViewController.tabViewModel!
        while tabViewModel.tab.isLoading {
            try await Task.sleep(nanoseconds: UInt64(100 * Double(NSEC_PER_MSEC)))
        }

        // assert
        let basicAuthStrippedFromAddressBar = tabViewModel.addressBarString == "https://example.com/"
        XCTAssertTrue(basicAuthStrippedFromAddressBar)
    }

    @MainActor
    func testUrlBarSpoofingWithFormAction() async throws {
        let tab = Tab(content: .none)
        window = WindowsManager.openNewWindow(with: tab)!

        let url = URL(string: "https://privacy-test-pages.site/security/address-bar-spoofing/spoof-form-action.html")!
        PrivacySecurityPreferences.shared.gpcEnabled = false
        _ = try await tab.setUrl(url, userEntered: nil)?.result.get()

        // run
        _ = try await tab.webView.evaluateJavaScript("(function() { run(); return true; })()")

        // wait
        try await Task.sleep(nanoseconds: UInt64(500 * Double(NSEC_PER_MSEC))) // wait for isLoading to be true, formactions are slow
        let tabViewModel = (window.contentViewController as! MainViewController).browserTabViewController.tabViewModel!
        while tabViewModel.tab.isLoading {
            try await Task.sleep(nanoseconds: UInt64(100 * Double(NSEC_PER_MSEC)))
        }

        // assert
        let spoofedContent = try await tabViewModel.tab.webView.find("Not DDG.")
        let addressBarUpdated = tabViewModel.addressBarString == "https://duckduckgo.com/"
        let addressBarEmpty = tabViewModel.addressBarString == ""
        XCTAssertTrue(addressBarUpdated || addressBarEmpty)
        XCTAssertTrue(!spoofedContent.matchFound)
    }

    @MainActor
    func testUrlBarSpoofingWithJsDownloadUrl() async throws {
        let tab = Tab(content: .none)
        window = WindowsManager.openNewWindow(with: tab)!

        let url = URL(string: "https://privacy-test-pages.site/security/address-bar-spoofing/spoof-js-download-url.html")!
        PrivacySecurityPreferences.shared.gpcEnabled = false
        _ = try await tab.setUrl(url, userEntered: nil)?.result.get()

        // run
        _ = try await tab.webView.evaluateJavaScript("(function() { run(); return true; })()")

        // wait
        try await Task.sleep(nanoseconds: UInt64(100 * Double(NSEC_PER_MSEC))) // wait for isLoading to be true
        let tabViewModel = (window.contentViewController as! MainViewController).browserTabViewController.tabViewModel!
        while tabViewModel.tab.isLoading {
            try await Task.sleep(nanoseconds: UInt64(100 * Double(NSEC_PER_MSEC)))
        }

        // assert
        let addressBarNotUpdated = tabViewModel.addressBarString == "https://privacy-test-pages.site/security/address-bar-spoofing/spoof-js-download-url.html"
        let addressBarAboutBlank = tabViewModel.addressBarString == "about:blank"
        XCTAssertTrue(addressBarAboutBlank || addressBarNotUpdated)
    }

    @MainActor
    func testUrlBarSpoofingWithOpenB64Html() async throws {
        let tab = Tab(content: .none)
        window = WindowsManager.openNewWindow(with: tab)!

        let url = URL(string: "https://privacy-test-pages.site/security/address-bar-spoofing/spoof-open-b64-html.html")!
        PrivacySecurityPreferences.shared.gpcEnabled = false
        _ = try await tab.setUrl(url, userEntered: nil)?.result.get()

        // run
        _ = try await tab.webView.evaluateJavaScript("(function() { run(); return true; })()")

        // wait
        try await Task.sleep(nanoseconds: UInt64(100 * Double(NSEC_PER_MSEC))) // wait for isLoading to be true
        let tabViewModel = (window.contentViewController as! MainViewController).browserTabViewController.tabViewModel!
        while tabViewModel.tab.isLoading {
            try await Task.sleep(nanoseconds: UInt64(100 * Double(NSEC_PER_MSEC)))
        }

        // assert
        let spoofedContent = try await tabViewModel.tab.webView.find("Not DDG.")
        let addressBarEmpty = tabViewModel.addressBarString == ""
        let addressBarIsData = tabViewModel.addressBarString.starts(with: "data:text/html")
        XCTAssertTrue(addressBarEmpty || addressBarIsData)
        XCTAssertTrue(!spoofedContent.matchFound)
    }

    @MainActor
    func testUrlBarSpoofingWithUnsupportedScheme() async throws {
        let tab = Tab(content: .none)
        window = WindowsManager.openNewWindow(with: tab)!

        let url = URL(string: "https://privacy-test-pages.site/security/address-bar-spoofing/spoof-unsupported-scheme.html")!
        PrivacySecurityPreferences.shared.gpcEnabled = false
        _ = try await tab.setUrl(url, userEntered: nil)?.result.get()

        // run
        _ = try await tab.webView.evaluateJavaScript("(function() { run(); return true; })()")

        // wait
        try await Task.sleep(nanoseconds: UInt64(100 * Double(NSEC_PER_MSEC))) // wait for isLoading to be true
        let tabViewModel = (window.contentViewController as! MainViewController).browserTabViewController.tabViewModel!
        while tabViewModel.tab.isLoading {
            try await Task.sleep(nanoseconds: UInt64(100 * Double(NSEC_PER_MSEC)))
        }

        // assert
        let addressBarNotUpdated = tabViewModel.addressBarString == "https://privacy-test-pages.site/security/address-bar-spoofing/spoof-unsupported-scheme.html"
        XCTAssertTrue(addressBarNotUpdated)
    }

}
