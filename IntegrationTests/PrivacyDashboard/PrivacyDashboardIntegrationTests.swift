//
//  PrivacyDashboardIntegrationTests.swift
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
class PrivacyDashboardIntegrationTests: XCTestCase {

    var window: NSWindow!
    var tabViewModel: TabViewModel {
        (window.contentViewController as! MainViewController).browserTabViewController.tabViewModel!
    }

    @MainActor
    override func setUp() {
        // disable GPC redirects
        WebTrackingProtectionPreferences.shared.isGPCEnabled = false

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
    func testWhenTrackerDetected_trackerInfoUpdated() async throws {
        let persistor = DownloadsPreferencesUserDefaultsPersistor()
        persistor.selectedDownloadLocation = FileManager.default.temporaryDirectory.absoluteString

        let tabViewModel = self.tabViewModel
        let tab = tabViewModel.tab

        // expect 1 detected tracker
        let trackersCountPromise = tab.privacyInfoPublisher.compactMap { $0?.$trackerInfo }
            .switchToLatest()
            .filter { $0.trackersBlocked.count > 0 }
            .map { $0.trackers.count }
            .timeout(10)
            .first()
            .promise()

        // load the test page
        let url = URL(string: "http://privacy-test-pages.site/tracker-reporting/1major-via-script.html")!
        _=await tab.setUrl(url, source: .link)?.result

        let trackersCount = try await trackersCountPromise.value
        XCTAssertEqual(trackersCount, 1)

        // navigate to a regular page, tracker count should be reset to 0
        let trackersCountPromise2 = tab.privacyInfoPublisher.compactMap { $0?.$trackerInfo }
            .switchToLatest()
            .filter { $0.trackersBlocked.count == 0 }
            .map { $0.trackers.count }
            .timeout(10)
            .first()
            .promise()
        _=await tab.setUrl(URL.testsServer, source: .link)?.result

        let trackersCount2 = try await trackersCountPromise2.value
        XCTAssertEqual(trackersCount2, 0)
    }

    @MainActor
    func testWhenPhishingDetected_phishingInfoUpdated() async throws {
        let tabViewModel = self.tabViewModel
        let tab = tabViewModel.tab

        let isPhishingPromise = tab.privacyInfoPublisher
            .compactMap {
                $0?.$malicousSiteThreatKind
            }
            .map { _ in true }
            .timeout(10)
            .first()
            .promise()
        // Load the test page
        let url = URL(string: "http://privacy-test-pages.site/security/badware/phishing.html")!
        _ = await tab.setUrl(url, source: .link)?.result

        let isPhishing = try await isPhishingPromise.value
        XCTAssertTrue(isPhishing)
    }

}
