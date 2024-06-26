//
//  DuckPlayerTests.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

import BrowserServicesKit
import Combine
import XCTest
import Common

@testable import DuckDuckGo_Privacy_Browser

final class DuckPlayerTests: XCTestCase {

    var duckPlayer: DuckPlayer!

    override func setUpWithError() throws {
        try super.setUpWithError()
        duckPlayer = DuckPlayer(
            preferences: .init(persistor: DuckPlayerPreferencesPersistorMock()),
            privacyConfigurationManager: MockPrivacyConfigurationManager()
        )
    }

    func testThatImageForFaviconViewReturnsHardcodedFaviconForDuckPlayer() {
        let duckPlayerFaviconView = FaviconView(url: duckPlayerURL())
        let otherFaviconView = FaviconView(url: URL(string: "http://example.com")!)

        duckPlayer.mode = .enabled
        XCTAssertEqual(duckPlayer.image(for: duckPlayerFaviconView)?.tiffRepresentation, NSImage.duckPlayer.tiffRepresentation)
        XCTAssertNil(duckPlayer.image(for: otherFaviconView))

        duckPlayer.mode = .alwaysAsk
        XCTAssertEqual(duckPlayer.image(for: duckPlayerFaviconView)?.tiffRepresentation, NSImage.duckPlayer.tiffRepresentation)
        XCTAssertNil(duckPlayer.image(for: otherFaviconView))

        duckPlayer.mode = .disabled
        XCTAssertNil(duckPlayer.image(for: duckPlayerFaviconView))
        XCTAssertNil(duckPlayer.image(for: otherFaviconView))
    }

    func testThatDomainForRecentlyVisitedSiteIsReturnedForDuckPlayerURLs() {
        duckPlayer.mode = .enabled
        XCTAssertEqual(duckPlayer.domainForRecentlyVisitedSite(with: duckPlayerURL()), DuckPlayer.commonName)
        XCTAssertNil(duckPlayer.domainForRecentlyVisitedSite(with: "https://duck.com".url!))

        duckPlayer.mode = .alwaysAsk
        XCTAssertEqual(duckPlayer.domainForRecentlyVisitedSite(with: duckPlayerURL()), DuckPlayer.commonName)
        XCTAssertNil(duckPlayer.domainForRecentlyVisitedSite(with: "https://duck.com".url!))

        duckPlayer.mode = .disabled
        XCTAssertEqual(duckPlayer.domainForRecentlyVisitedSite(with: duckPlayerURL()), nil)
        XCTAssertNil(duckPlayer.domainForRecentlyVisitedSite(with: "https://duck.com".url!))
    }

    func testThatSharingDataStripsDuckPlayerPrefixFromTitleAndReturnsYoutubeURL() {
        let sharingData = duckPlayer.sharingData(for: "\(UserText.duckPlayer) - sample video", url: "duck://player/12345678?t=10".url!)
        XCTAssertEqual(sharingData?.title, "sample video")
        XCTAssertEqual(sharingData?.url, URL.youtube("12345678", timestamp: "10"))
    }

    func testThatSharingDataForNonDuckPlayerURLReturnsNil() {
        XCTAssertNil(duckPlayer.sharingData(for: "Wikipedia", url: "https://wikipedia.org".url!))
    }

    func testThatTitleForRecentlyVisitedPageIsGeneratedForDuckPlayerFeedItems() {
        let feedItem = HomePage.Models.RecentlyVisitedPageModel(
            actualTitle: "\(UserText.duckPlayer) - A sample video title",
            url: duckPlayerURL(),
            visited: Date()
        )

        duckPlayer.mode = .enabled
        XCTAssertEqual(duckPlayer.title(for: feedItem), "A sample video title")

        duckPlayer.mode = .disabled
        XCTAssertNil(duckPlayer.title(for: feedItem))
    }

    @MainActor
    func testEnabledPiPFlag() async {
        let configuration = WKWebViewConfiguration()

        configuration.applyStandardConfiguration(contentBlocking: ContentBlockingMock(),
                                                 burnerMode: .regular)
#if APPSTORE
        XCTAssertFalse(configuration.allowsPictureInPictureMediaPlayback)
#else
        XCTAssertTrue(configuration.allowsPictureInPictureMediaPlayback)
#endif
    }

    func testThatTitleForRecentlyVisitedPageIsNotAdjustedForNonDuckPlayerFeedItems() {
        let feedItem = HomePage.Models.RecentlyVisitedPageModel(
            actualTitle: "Duck Player - A sample video title",
            url: "https://duck.com".url!,
            visited: Date()
        )

        duckPlayer.mode = .enabled
        XCTAssertNil(duckPlayer.title(for: feedItem))
    }

    private func duckPlayerURL() -> URL {
        if #available(macOS 12.0, *) {
            return .youtubeNoCookie("12345678")
        } else {
            return .duckPlayer("12345678")
        }
    }
}

extension WKWebViewConfiguration {
    var allowsPictureInPictureMediaPlayback: Bool {
        get { preferences[.allowsPictureInPictureMediaPlayback] }
        set { preferences[.allowsPictureInPictureMediaPlayback] = newValue }
    }
}
