//
//  RecentActivityProviderTests.swift
//
//  Copyright © 2025 DuckDuckGo. All rights reserved.
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

import Common
import History
import NewTabPage
import XCTest
@testable import DuckDuckGo_Privacy_Browser

final class MockURLFavoriteStatusProvider: URLFavoriteStatusProviding {
    func isUrlFavorited(url: URL) -> Bool {
        isUrlFavorited(url)
    }

    var isUrlFavorited: (URL) -> Bool = { _ in false }
}

final class MockURLFireproofStatusProvider: URLFireproofStatusProviding {
    func isDomainFireproof(forURL url: URL) -> Bool {
        isDomainFireproof(url)
    }

    var isDomainFireproof: (URL) -> Bool = { _ in false }
}

final class MockDuckPlayerHistoryEntryTitleProvider: DuckPlayerHistoryEntryTitleProviding {
    func title(for historyEntry: NewTabPageDataModel.HistoryEntry) -> String? {
        titleForHistoryEntry(historyEntry)
    }

    var titleForHistoryEntry: (NewTabPageDataModel.HistoryEntry) -> String? = { _ in nil }
}

final class MockTrackerEntityPrevalenceComparator: TrackerEntityPrevalenceComparing {
    func isPrevalence(for lhsEntityName: String, greaterThan rhsEntityName: String) -> Bool {
        // comparing names to simplify testing
        return lhsEntityName.localizedCaseInsensitiveCompare(rhsEntityName) == .orderedAscending
    }
}

final class RecentActivityProviderTests: XCTestCase {
    var provider: RecentActivityProvider!
    var historyCoordinator: HistoryCoordinatingMock!
    var urlFavoriteStatusProvider: MockURLFavoriteStatusProvider!
    var duckPlayerHistoryEntryTitleProvider: MockDuckPlayerHistoryEntryTitleProvider!

    override func setUp() async throws {
        try await super.setUp()

        historyCoordinator = HistoryCoordinatingMock()
        urlFavoriteStatusProvider = MockURLFavoriteStatusProvider()
        duckPlayerHistoryEntryTitleProvider = MockDuckPlayerHistoryEntryTitleProvider()
        provider = RecentActivityProvider(
            historyCoordinator: historyCoordinator,
            urlFavoriteStatusProvider: urlFavoriteStatusProvider,
            duckPlayerHistoryEntryTitleProvider: duckPlayerHistoryEntryTitleProvider,
            trackerEntityPrevalenceComparator: MockTrackerEntityPrevalenceComparator()
        )
    }

    func testWhenHistoryIsEmptyThenActivityIsEmpty() throws {
        historyCoordinator.history = []

        XCTAssertEqual(provider.refreshActivity(), [])
    }

    func testWhenHistoryEntryHasVisitsToRootURLThenActivityHasNoHistory() throws {
        let uuid = UUID()
        let url = try XCTUnwrap("https://example.com".url)

        historyCoordinator.history = [
            .make(identifier: uuid, url: url, lastVisit: Date())
        ]

        XCTAssertEqual(
            provider.refreshActivity(),
            [
                .init(
                    id: uuid.uuidString,
                    title: "example.com",
                    url: "https://example.com",
                    etldPlusOne: "example.com",
                    favicon: .init(maxAvailableSize: 32, src: try XCTUnwrap(URL.duckFavicon(for: url)?.absoluteString)),
                    favorite: false,
                    trackersFound: false,
                    trackingStatus: .init(totalCount: 0, trackerCompanies: []),
                    history: []
                )
            ]
        )
    }

    func testWhenHistoryEntryHasVisitsToNonRootURLThenActivityHasOneEntryWithHistory() throws {
        let uuid = UUID()
        let url = try XCTUnwrap("https://example.com".url)

        historyCoordinator.history = [
            .make(identifier: uuid, url: url.appending("index.html"), lastVisit: Date())
        ]

        XCTAssertEqual(
            provider.refreshActivity(),
            [
                .init(
                    id: uuid.uuidString,
                    title: "example.com",
                    url: "https://example.com",
                    etldPlusOne: "example.com",
                    favicon: .init(maxAvailableSize: 32, src: try XCTUnwrap(URL.duckFavicon(for: url)?.absoluteString)),
                    favorite: false,
                    trackersFound: false,
                    trackingStatus: .init(totalCount: 0, trackerCompanies: []),
                    history: [
                        .init(relativeTime: UserText.justNow, title: "/index.html", url: "https://example.com/index.html")
                    ]
                )
            ]
        )
    }

    func testWhenHistoryEntryHasVisitsToDifferentNonRootURLsOfTheSameDomainThenActivityHasOneEntryWithHistory() throws {
        let uuid = UUID()
        let url = try XCTUnwrap("https://example.com".url)
        let date = Date()

        historyCoordinator.history = [
            .make(identifier: uuid, url: url.appending("index1.html"), lastVisit: date),
            .make(identifier: uuid, url: url.appending("index2.html"), lastVisit: date.addingTimeInterval(-1)),
            .make(identifier: uuid, url: url.appending("index3.html"), lastVisit: date.addingTimeInterval(-2))
        ]

        XCTAssertEqual(
            provider.refreshActivity(),
            [
                .init(
                    id: uuid.uuidString,
                    title: "example.com",
                    url: "https://example.com",
                    etldPlusOne: "example.com",
                    favicon: .init(maxAvailableSize: 32, src: try XCTUnwrap(URL.duckFavicon(for: url)?.absoluteString)),
                    favorite: false,
                    trackersFound: false,
                    trackingStatus: .init(totalCount: 0, trackerCompanies: []),
                    history: [
                        .init(relativeTime: UserText.justNow, title: "/index1.html", url: "https://example.com/index1.html"),
                        .init(relativeTime: UserText.justNow, title: "/index2.html", url: "https://example.com/index2.html"),
                        .init(relativeTime: UserText.justNow, title: "/index3.html", url: "https://example.com/index3.html")
                    ]
                )
            ]
        )
    }

    func testThatHistoryEntryDisplaysSumOfBlockedTrackersForVisitsToAllURLsOfTheSameDomain() throws {
        let uuid = UUID()
        let url = try XCTUnwrap("https://example.com".url)
        let date = Date()

        historyCoordinator.history = [
            .make(identifier: uuid, url: url.appending("index1.html"), lastVisit: date, numberOfTrackersBlocked: 1, blockedTrackingEntities: ["a"]),
            .make(identifier: uuid, url: url.appending("index2.html"), lastVisit: date.addingTimeInterval(-1), numberOfTrackersBlocked: 2, blockedTrackingEntities: ["b"]),
            .make(identifier: uuid, url: url.appending("index3.html"), lastVisit: date.addingTimeInterval(-2), numberOfTrackersBlocked: 4, blockedTrackingEntities: ["c", "d"])
        ]

        XCTAssertEqual(
            provider.refreshActivity(),
            [
                .init(
                    id: uuid.uuidString,
                    title: "example.com",
                    url: "https://example.com",
                    etldPlusOne: "example.com",
                    favicon: .init(maxAvailableSize: 32, src: try XCTUnwrap(URL.duckFavicon(for: url)?.absoluteString)),
                    favorite: false,
                    trackersFound: false,
                    trackingStatus: .init(
                        totalCount: 7,
                        trackerCompanies: [
                            .init(displayName: "a"), .init(displayName: "b"), .init(displayName: "c"), .init(displayName: "d")
                        ]
                    ),
                    history: [
                        .init(relativeTime: UserText.justNow, title: "/index1.html", url: "https://example.com/index1.html"),
                        .init(relativeTime: UserText.justNow, title: "/index2.html", url: "https://example.com/index2.html"),
                        .init(relativeTime: UserText.justNow, title: "/index3.html", url: "https://example.com/index3.html")
                    ]
                )
            ]
        )
    }

    func testThatHistoryEntryFiltersOutEmptyTrackerCompanies() throws {
        let uuid = UUID()
        let url = try XCTUnwrap("https://example.com".url)
        let date = Date()

        historyCoordinator.history = [
            .make(identifier: uuid, url: url.appending("index1.html"), lastVisit: date, numberOfTrackersBlocked: 10, blockedTrackingEntities: ["", "a"])
        ]

        XCTAssertEqual(
            provider.refreshActivity(),
            [
                .init(
                    id: uuid.uuidString,
                    title: "example.com",
                    url: "https://example.com",
                    etldPlusOne: "example.com",
                    favicon: .init(maxAvailableSize: 32, src: try XCTUnwrap(URL.duckFavicon(for: url)?.absoluteString)),
                    favorite: false,
                    trackersFound: false,
                    trackingStatus: .init(
                        totalCount: 10,
                        trackerCompanies: [
                            .init(displayName: "a")
                        ]
                    ),
                    history: [
                        .init(relativeTime: UserText.justNow, title: "/index1.html", url: "https://example.com/index1.html"),
                    ]
                )
            ]
        )
    }

    func testWhenHistoryEntryHasVisitsToTwoDifferentDomainsThenActivityHasTwoEntries() throws {
        let uuid = UUID()
        let url1 = try XCTUnwrap("https://example.com".url)
        let url2 = try XCTUnwrap("https://example2.com".url)
        let date = Date()

        historyCoordinator.history = [
            .make(identifier: uuid, url: url1.appending("index1.html"), lastVisit: date),
            .make(identifier: uuid, url: url1.appending("index2.html"), lastVisit: date.addingTimeInterval(-1)),
            .make(identifier: uuid, url: url2.appending("index3.html"), lastVisit: date.addingTimeInterval(-2)),
            .make(identifier: uuid, url: url2.appending("index4.html"), lastVisit: date.addingTimeInterval(-3))
        ]

        XCTAssertEqual(
            provider.refreshActivity(),
            [
                .init(
                    id: uuid.uuidString,
                    title: "example.com",
                    url: "https://example.com",
                    etldPlusOne: "example.com",
                    favicon: .init(maxAvailableSize: 32, src: try XCTUnwrap(URL.duckFavicon(for: url1)?.absoluteString)),
                    favorite: false,
                    trackersFound: false,
                    trackingStatus: .init(totalCount: 0, trackerCompanies: []),
                    history: [
                        .init(relativeTime: UserText.justNow, title: "/index1.html", url: "https://example.com/index1.html"),
                        .init(relativeTime: UserText.justNow, title: "/index2.html", url: "https://example.com/index2.html"),
                    ]
                ),
                .init(
                    id: uuid.uuidString,
                    title: "example2.com",
                    url: "https://example2.com",
                    etldPlusOne: "example2.com",
                    favicon: .init(maxAvailableSize: 32, src: try XCTUnwrap(URL.duckFavicon(for: url2)?.absoluteString)),
                    favorite: false,
                    trackersFound: false,
                    trackingStatus: .init(totalCount: 0, trackerCompanies: []),
                    history: [
                        .init(relativeTime: UserText.justNow, title: "/index3.html", url: "https://example2.com/index3.html"),
                        .init(relativeTime: UserText.justNow, title: "/index4.html", url: "https://example2.com/index4.html")
                    ]
                )
            ]
        )
    }

    func testThatHistoryEntryThatFailedToLoadIsFilteredOutInActivity() throws {
        let uuid = UUID()
        let url = try XCTUnwrap("https://example.com".url)
        let date = Date()

        historyCoordinator.history = [
            .make(identifier: uuid, url: url, failedToLoad: true, lastVisit: date)
        ]

        XCTAssertEqual(provider.refreshActivity(), [])
    }

    func testWhenHistoryEntryHasTrackerStatsThenActivityHasEntryWithTrackerStats() throws {
        let uuid = UUID()
        let url = try XCTUnwrap("https://example.com".url)

        historyCoordinator.history = [
            .make(identifier: uuid, url: url, lastVisit: Date(), numberOfTrackersBlocked: 40, blockedTrackingEntities: ["A", "B", "C"])
        ]

        XCTAssertEqual(
            provider.refreshActivity(),
            [
                .init(
                    id: uuid.uuidString,
                    title: "example.com",
                    url: "https://example.com",
                    etldPlusOne: "example.com",
                    favicon: .init(maxAvailableSize: 32, src: try XCTUnwrap(URL.duckFavicon(for: url)?.absoluteString)),
                    favorite: false,
                    trackersFound: false,
                    trackingStatus: .init(totalCount: 40, trackerCompanies: [.init(displayName: "A"), .init(displayName: "B"), .init(displayName: "C")]),
                    history: []
                )
            ]
        )
    }

    func testThatHistoryEntryForDDGSearchHasPrettifiedTitle() throws {
        let uuid = UUID()
        let url = try XCTUnwrap(URL.makeSearchUrl(from: "hello"))

        historyCoordinator.history = [
            .make(identifier: uuid, url: url, lastVisit: Date())
        ]

        XCTAssertEqual(
            provider.refreshActivity(),
            [
                .init(
                    id: uuid.uuidString,
                    title: "duckduckgo.com",
                    url: "https://duckduckgo.com",
                    etldPlusOne: "duckduckgo.com",
                    favicon: .init(maxAvailableSize: 32, src: try XCTUnwrap(URL.duckFavicon(for: "https://duckduckgo.com".url!)?.absoluteString)),
                    favorite: false,
                    trackersFound: false,
                    trackingStatus: .init(totalCount: 0, trackerCompanies: []),
                    history: [
                        .init(relativeTime: UserText.justNow, title: "hello", url: url.absoluteString),
                    ]
                )
            ]
        )
    }
}

private extension HistoryEntry {
    static func make(
        identifier: UUID,
        url: URL,
        title: String? = nil,
        failedToLoad: Bool = false,
        numberOfTotalVisits: Int = 1,
        lastVisit: Date,
        visits: Set<Visit> = [],
        numberOfTrackersBlocked: Int = 0,
        blockedTrackingEntities: Set<String> = [],
        trackersFound: Bool = false
    ) -> HistoryEntry {
        HistoryEntry(
            identifier: identifier,
            url: url,
            title: title,
            failedToLoad: failedToLoad,
            numberOfTotalVisits: numberOfTotalVisits,
            lastVisit: lastVisit,
            visits: visits,
            numberOfTrackersBlocked: numberOfTrackersBlocked,
            blockedTrackingEntities: blockedTrackingEntities,
            trackersFound: trackersFound
        )
    }
}
