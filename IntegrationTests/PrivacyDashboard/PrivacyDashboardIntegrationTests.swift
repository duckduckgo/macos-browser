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
    func testWhenTrackerDetected_trackerInfoUpdated() async throws {
        var persistor = DownloadsPreferencesUserDefaultsPersistor()
        persistor.selectedDownloadLocation = FileManager.default.temporaryDirectory.absoluteString

        let tabViewModel = self.tabViewModel
        let tab = tabViewModel.tab

        // expect 1 detected tracker
        let trackersCountPromise = tab.privacyInfoPublisher.compactMap { $0?.$trackerInfo }
            .switchToLatest()
            .filter { $0.trackersBlocked.count > 0 }
            .map { $0.trackers.count }
            .timeout(5)
            .first()
            .promise()

        // load the test page
        let url = URL(string: "http://privacy-test-pages.glitch.me/tracker-reporting/1major-via-script.html")!
        _=await tab.setUrl(url, userEntered: false)?.value?.result

        let trackersCount = try await trackersCountPromise.value
        XCTAssertEqual(trackersCount, 1)

        // navigate to a regular page, tracker count should be reset to 0
        let trackersCountPromise2 = tab.privacyInfoPublisher.compactMap { $0?.$trackerInfo }
            .switchToLatest()
            .filter { $0.trackersBlocked.count == 0 }
            .map { $0.trackers.count }
            .timeout(5)
            .first()
            .promise()
        _=await tab.setUrl(URL.testsServer, userEntered: false)?.value?.result

        let trackersCount2 = try await trackersCountPromise2.value
        XCTAssertEqual(trackersCount2, 0)
    }

}
