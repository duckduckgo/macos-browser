//
//  HTTPSUpgradeIntegrationTests.swift
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
import XCTest

@testable import DuckDuckGo_Privacy_Browser

@available(macOS 12.0, *)
class HTTPSUpgradeIntegrationTests: XCTestCase {

    var window: NSWindow!

    var mainViewController: MainViewController {
        (window.contentViewController as! MainViewController)
    }

    var tabViewModel: TabViewModel {
        mainViewController.browserTabViewController.tabViewModel!
    }

    @MainActor
    override func setUp() async throws {
        // disable GPC redirects
        WebTrackingProtectionPreferences.shared.isGPCEnabled = false

        window = WindowsManager.openNewWindow(with: .none)!

        XCTAssertTrue(AppPrivacyFeatures.shared.contentBlocking.privacyConfigurationManager.privacyConfig.isFeature(.httpsUpgrade, enabledForDomain: "privacy-test-pages.site"))
    }

    @MainActor
    override func tearDown() async throws {
        window.close()
        window = nil

        WebTrackingProtectionPreferences.shared.isGPCEnabled = true
    }

    // MARK: - Tests

    @MainActor
    func testHttpsUpgrade() async throws {
        let persistor = DownloadsPreferencesUserDefaultsPersistor()
        persistor.selectedDownloadLocation = FileManager.default.temporaryDirectory.absoluteString

        let url = URL(string: "http://privacy-test-pages.site/privacy-protections/https-upgrades/")!
        let upgradableUrl = URL(string: "http://good.third-party.site/privacy-protections/https-upgrades/frame.html")!
        let upgradedUrl = try? await AppPrivacyFeatures.shared.httpsUpgrade.upgrade(url: upgradableUrl).get()
        XCTAssertEqual(upgradedUrl, upgradableUrl.toHttps()!, "URL not upgraded")

        let tabViewModel = self.tabViewModel
        let tab = tabViewModel.tab

        _=await tab.setUrl(url, source: .link)?.result

        // expect popup to open and then close
        var oldValue: TabViewModel! = self.tabViewModel
        let comingBackToFirstTabPromise = mainViewController.tabCollectionViewModel
            .$selectedTabViewModel
            .filter { newValue in
                if newValue === tabViewModel && oldValue !== newValue {
                    // returning back from popup window: pass published value further
                    return true
                }
                oldValue = newValue
                return false
            }
            .asVoid()
            .timeout(5)
            .first()
            .promise()

        // run test
        try await tab.webView.evaluateJavaScript("(function() { document.getElementById('start').click(); })()") as Void?

        // await for popup to open and close
        _=try await comingBackToFirstTabPromise.value

        let downloadTaskFuture = FileDownloadManager.shared.downloadsPublisher.timeout(5).first().promise()

        // download results
        try await tab.webView.evaluateJavaScript("(function() { document.getElementById('download').click(); })()") as Void?

        let fileUrl = try await downloadTaskFuture.value.output
            .timeout(1, scheduler: DispatchQueue.main) { .init(TimeoutError() as NSError) }.first().promise().get()

        struct Results: Decodable {
            struct Result: Decodable {
                let id: String
                let value: URL?
            }
            let results: [Result]
        }
        let results = try JSONDecoder().decode(Results.self, from: Data(contentsOf: fileUrl))
        let upgradeNavigation = results.results.first(where: { $0.id == "upgrade-navigation" })

        XCTAssertNotNil(upgradeNavigation)
        XCTAssertEqual(upgradeNavigation?.value, upgradedUrl)
    }

    @MainActor
    func testHttpsLoopProtection() async throws {
        let persistor = DownloadsPreferencesUserDefaultsPersistor()
        persistor.selectedDownloadLocation = FileManager.default.temporaryDirectory.absoluteString

        let url = URL(string: "http://privacy-test-pages.site/privacy-protections/https-loop-protection/")!

        let tabViewModel = self.tabViewModel
        let tab = tabViewModel.tab

        _=await tab.setUrl(url, source: .link)?.result

        // expect popup to open and then close
        var oldValue: TabViewModel! = self.tabViewModel
        let comingBackToFirstTabPromise = mainViewController.tabCollectionViewModel
            .$selectedTabViewModel
            .filter { newValue in
                if newValue === tabViewModel && oldValue !== newValue {
                    // returning back from popup window: pass published value further
                    return true
                }
                oldValue = newValue
                return false
            }
            .asVoid()
            .timeout(5)
            .first()
            .promise()

        // expect connectionUpgradedTo to be published
        let connectionUpgradedPromise = mainViewController.tabCollectionViewModel
            .$selectedTabViewModel
            .filter {
                $0 !== tabViewModel
            }
            .compactMap {
                $0?.tab.privacyInfoPublisher
            }
            .switchToLatest()
            .compactMap {
                $0?.$connectionUpgradedTo
            }
            .switchToLatest()
            .filter {
                $0 != nil
            }
            .timeout(5)
            .first()
            .promise()

        // run test
        try await tab.webView.evaluateJavaScript("(function() { document.getElementById('start').click(); })()") as Void?

        // await for popup to open and close
        _=try await comingBackToFirstTabPromise.value

        let downloadTaskFuture = FileDownloadManager.shared.downloadsPublisher.timeout(5).first().promise()

        // download results
        try await tab.webView.evaluateJavaScript("(function() { document.getElementById('download').click(); })()") as Void?

        let fileUrl = try await downloadTaskFuture.value.output
            .timeout(1, scheduler: DispatchQueue.main) { .init(TimeoutError() as NSError) }.first().promise().get()

        struct Results: Decodable {
            struct Result: Decodable {
                let id: String
                let value: URL?
            }
            let results: [Result]
        }
        let results = try JSONDecoder().decode(Results.self, from: Data(contentsOf: fileUrl))
        let upgradeNavigation = results.results.first(where: { $0.id == "upgrade-navigation" })

        let connectionUpgradedTo = try await connectionUpgradedPromise.value

        XCTAssertNotNil(upgradeNavigation)
        XCTAssertEqual(upgradeNavigation?.value, URL(string: "http://good.third-party.site/privacy-protections/https-loop-protection/http-only.html")!)
        XCTAssertEqual(connectionUpgradedTo, URL(string: "https://good.third-party.site/privacy-protections/https-loop-protection/http-only.html")!)
    }

}
