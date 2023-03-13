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

    static var window: NSWindow!
    var tabViewModel: TabViewModel {
        (Self.window.contentViewController as! MainViewController).browserTabViewController.tabViewModel!
    }

    override class func setUp() {
        // disable GPC redirects
        PrivacySecurityPreferences.shared.gpcEnabled = false

        window = WindowsManager.openNewWindow(with: .none)!
    }

    override class func tearDown() {
        window.close()
        window = nil

        PrivacySecurityPreferences.shared.gpcEnabled = true
    }

    // MARK: - Tests
    // Uses tests-server helper tool for mocking HTTP requests (see tests-server/main.swift)

    @MainActor
    func testWhenShouldDownloadResponse_downloadStarts() async throws {
        var persistor = DownloadsPreferencesUserDefaultsPersistor()
        persistor.selectedDownloadLocation = FileManager.default.temporaryDirectory.absoluteString

        let url = URL(string: "http://privacy-test-pages.glitch.me/privacy-protections/https-upgrades/")!

        let tabViewModel = self.tabViewModel
        let tab = tabViewModel.tab

        _=await tab.setUrl(url, userEntered: false)?.value?.result

        // expect popup to open and then close
        var oldValue: TabViewModel! = self.tabViewModel
        let comingBackToFirstTabPromise = (Self.window.contentViewController as! MainViewController).tabCollectionViewModel
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
        _=try await tab.webView.evaluateJavaScript("(function() { document.getElementById('start').click(); return true })()")

        // await for popup to open and close
        _=try await comingBackToFirstTabPromise.value

        let downloadTaskFuture = FileDownloadManager.shared.downloadsPublisher.timeout(5).first().promise()

        // download results
        _=try await tab.webView.evaluateJavaScript("(function() { document.getElementById('download').click(); return true })()")

        let fileUrl = try await downloadTaskFuture.get().output
            .timeout(1, scheduler: DispatchQueue.main) { .init(TimeoutError() as NSError, isRetryable: false) }.first().promise().get()

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
        XCTAssertEqual(upgradeNavigation?.value, URL(string: "https://good.third-party.site/privacy-protections/https-upgrades/frame.html")!)
    }

}
