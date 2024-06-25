//
//  HistoryIntegrationTests.swift
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
import History
import Navigation
import XCTest

@testable import DuckDuckGo_Privacy_Browser

@available(macOS 12.0, *)
class HistoryIntegrationTests: XCTestCase {

    var window: NSWindow!

    var mainViewController: MainViewController {
        (window.contentViewController as! MainViewController)
    }

    var tabViewModel: TabViewModel {
        mainViewController.browserTabViewController.tabViewModel!
    }

    var contentBlockingMock: ContentBlockingMock!
    var privacyFeaturesMock: AnyPrivacyFeatures!
    var privacyConfiguration: MockPrivacyConfiguration {
        contentBlockingMock.privacyConfigurationManager.privacyConfig as! MockPrivacyConfiguration
    }

    @MainActor
    override func setUp() async throws {
        contentBlockingMock = ContentBlockingMock()
        privacyFeaturesMock = AppPrivacyFeatures(contentBlocking: contentBlockingMock, httpsUpgradeStore: HTTPSUpgradeStoreMock())
        // disable waiting for CBR compilation on navigation
        privacyConfiguration.isFeatureKeyEnabled = { _, _ in
            return false
        }

        await withCheckedContinuation { continuation in
            HistoryCoordinator.shared.burnAll {
                continuation.resume(returning: ())
            }
        }
    }

    @MainActor
    override func tearDown() async throws {
        window?.close()
        window = nil
        WebTrackingProtectionPreferences.shared.isGPCEnabled = true
    }

    // MARK: - Tests

    @MainActor
    func testWhenPageTitleIsUpdated_historyEntryTitleUpdated() async throws {
        let tab = Tab(content: .newtab, privacyFeatures: privacyFeaturesMock)
        window = WindowsManager.openNewWindow(with: tab)!

        let html = """
            <html>
                <head><title>Title 1</title></head>
                <body>test content</body>
            </html>
        """

        let url = URL.testsServer.appendingTestParameters(data: html.utf8data)
        let titleChangedPromise1 = tab.$title
            .filter { $0 == "Title 1" }
            .receive(on: DispatchQueue.main)
            .timeout(5, "Title 1")
            .first()
            .promise()

        _=try await tab.setUrl(url, source: .link)?.result.get()
        _=try await titleChangedPromise1.value

        XCTAssertEqual(HistoryCoordinator.shared.history?.count, 1)
        XCTAssertEqual(HistoryCoordinator.shared.history?.first?.title, "Title 1")
        XCTAssertEqual(HistoryCoordinator.shared.history?.first?.numberOfVisits, 1)
        XCTAssertEqual(HistoryCoordinator.shared.history?.first?.blockedTrackingEntities.isEmpty, true)

        let titleChangedPromise2 = tab.$title
            .filter { $0 == "Title 2" }
            .receive(on: DispatchQueue.main)
            .timeout(5, "Title 2")
            .first()
            .promise()

        try await tab.webView.evaluateJavaScript("(function() { document.title = 'Title 2'; })()") as Void?
        _=try await titleChangedPromise2.value

        XCTAssertEqual(HistoryCoordinator.shared.history?.count, 1)
        XCTAssertEqual(HistoryCoordinator.shared.history?.first?.title, "Title 2")
        XCTAssertEqual(HistoryCoordinator.shared.history?.first?.numberOfVisits, 1)
        XCTAssertEqual(HistoryCoordinator.shared.history?.first?.blockedTrackingEntities.isEmpty, true)
    }

    @MainActor
    func testWhenSameDocumentNavigation_historyEntryTitleUpdated() async throws {
        let tab = Tab(content: .newtab, privacyFeatures: privacyFeaturesMock)
        window = WindowsManager.openNewWindow(with: tab)!

        let html = """
            <html>
                <head><title>Title 1</title></head>
                <body>
                    <a id="link" href="#navlink" onclick="javascript:document.title='Title 2'">click me</a><br />
                    test content<br />
                    <a id="navlink"/><br />
                    test content 2<br />
                </body>
            </html>
        """

        let urls = [
            URL.testsServer.appendingTestParameters(data: html.utf8data),
            URL(string: URL.testsServer.appendingTestParameters(data: html.utf8data).absoluteString + "#1")!,
        ]

        _=try await tab.setUrl(urls[0], source: .link)?.result.get()

        let titleChangedPromise = tab.$title
            .filter { $0 == "Title 2" }
            .receive(on: DispatchQueue.main)
            .timeout(1, "Title 2")
            .first()
            .promise()

        try await tab.webView.evaluateJavaScript("(function() { document.getElementById('link').click(); })()") as Void?
        _=try await titleChangedPromise.value

        XCTAssertEqual(HistoryCoordinator.shared.history?.count, 2)
        let first = HistoryCoordinator.shared.history?.first(where: { $0.url == urls[0] })
        XCTAssertEqual(first?.numberOfVisits, 1)
        XCTAssertEqual(first?.title, "Title 1")

        let second = HistoryCoordinator.shared.history?.first(where: { $0.url != urls[0] })
        XCTAssertEqual(second?.numberOfVisits, 1)
        XCTAssertEqual(second?.title, "Title 2")
    }

    @MainActor
    func testWhenNavigatingToSamePage_visitIsAdded() async throws {
        let tab = Tab(content: .newtab, privacyFeatures: privacyFeaturesMock)
        window = WindowsManager.openNewWindow(with: tab)!

        let urls = [
            URL.testsServer,
            URL.testsServer.appendingPathComponent("page1").appendingTestParameters(data: "".utf8data),
        ]
        _=try await tab.setUrl(urls[0], source: .link)?.result.get()
        _=try await tab.setUrl(urls[1], source: .link)?.result.get()
        _=try await tab.setUrl(urls[0], source: .link)?.result.get()

        let first = HistoryCoordinator.shared.history?.first(where: { $0.url == urls[0] })
        XCTAssertEqual(first?.numberOfVisits, 2)

        let second = HistoryCoordinator.shared.history?.first(where: { $0.url == urls[1] })
        XCTAssertEqual(second?.numberOfVisits, 1)
    }

    @MainActor
    func testWhenNavigatingBack_visitIsNotAdded() async throws {
        let tab = Tab(content: .newtab, privacyFeatures: privacyFeaturesMock)
        window = WindowsManager.openNewWindow(with: tab)!

        let urls = [
            URL.testsServer,
            URL.testsServer.appendingPathComponent("page1").appendingTestParameters(data: "".utf8data),
        ]
        _=try await tab.setUrl(urls[0], source: .link)?.result.get()
        _=try await tab.setUrl(urls[1], source: .link)?.result.get()
        _=try await tab.goBack()?.result.get()
        _=try await tab.goForward()?.result.get()

        let first = HistoryCoordinator.shared.history?.first(where: { $0.url == urls[0] })
        XCTAssertEqual(first?.numberOfVisits, 1)

        let second = HistoryCoordinator.shared.history?.first(where: { $0.url == urls[1] })
        XCTAssertEqual(second?.numberOfVisits, 1)
    }

    @MainActor
    func testWhenScriptTrackerLoaded_trackerAddedToHistory() async throws {
        WebTrackingProtectionPreferences.shared.isGPCEnabled = false

        let tab = Tab(content: .newtab)
        window = WindowsManager.openNewWindow(with: tab)!

        let url = URL(string: "http://privacy-test-pages.site/tracker-reporting/1major-via-script.html")!

        // navigate to a regular page, tracker count should be reset to 0
        let trackerPromise = tab.privacyInfoPublisher.compactMap { $0?.$trackerInfo }
            .switchToLatest()
            .filter { $0.trackersBlocked.count == 1 }
            .map { _ in true }
            .timeout(5)
            .first()
            .promise()

        _=try await tab.setUrl(url, source: .link)?.result.get()
        _=try await trackerPromise.value

        let first = HistoryCoordinator.shared.history?.first
        XCTAssertEqual(first?.trackersFound, true)
        XCTAssertEqual(first?.numberOfTrackersBlocked, 2)
        XCTAssertEqual(first?.blockedTrackingEntities, ["Google Ads (Google)"])
        XCTAssertEqual(first?.numberOfVisits, 1)
    }

    @MainActor
    func testWhenSurrogateTrackerLoaded_trackerAddedToHistory() async throws {
        WebTrackingProtectionPreferences.shared.isGPCEnabled = false

        let tab = Tab(content: .newtab)
        window = WindowsManager.openNewWindow(with: tab)!

        let url = URL(string: "http://privacy-test-pages.site/tracker-reporting/1major-with-surrogate.html")!

        // navigate to a regular page, tracker count should be reset to 0
        let trackerPromise = tab.privacyInfoPublisher.compactMap { $0?.$trackerInfo }
            .switchToLatest()
            .filter { $0.trackersBlocked.count == 1 }
            .map { _ in true }
            .timeout(10)
            .first()
            .promise()

        _=try await tab.setUrl(url, source: .link)?.result.get()
        _=try await trackerPromise.value

        let first = HistoryCoordinator.shared.history?.first
        XCTAssertEqual(first?.trackersFound, true)
        XCTAssertEqual(first?.numberOfTrackersBlocked, 3)
        XCTAssertEqual(first?.blockedTrackingEntities, ["Google Ads (Google)"])
        XCTAssertEqual(first?.numberOfVisits, 1)
    }

}
