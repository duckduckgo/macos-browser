//
//  BookmarksBarVisibilityManagerTests.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

import XCTest
import Combine
@testable import DuckDuckGo_Privacy_Browser

final class BookmarksBarVisibilityManagerTests: XCTestCase {
    private let selectedTabSubject = PassthroughSubject<TabViewModel?, Never>()
    private var appearance: AppearancePreferences!
    private var cancellables: Set<AnyCancellable>!
    let tabContents: [Tab.TabContent] = [
        .none,
        .newtab,
        .url(URL.duckDuckGo, credential: nil, source: .link),
        .settings(pane: nil),
        .bookmarks,
        .onboardingDeprecated,
        .onboarding,
        .dataBrokerProtection,
        .subscription(URL.duckDuckGo),
        .identityTheftRestoration(URL.duckDuckGo)
    ]

    override func setUpWithError() throws {
        try super.setUpWithError()

        cancellables = []
        appearance = AppearancePreferences(persistor: AppearancePreferencesPersistorMock())
    }

    override func tearDownWithError() throws {
        cancellables = nil
        appearance = nil
        try super.tearDownWithError()
    }

    func makeSUT() -> BookmarksBarVisibilityManager {
        return BookmarksBarVisibilityManager(
            selectedTabPublisher: selectedTabSubject.eraseToAnyPublisher(),
            preferences: appearance
        )
    }

    func testWhenSubscribeThenIsBookmarksBarVisibleIsFalse() {
        // GIVEN
        let sut = makeSUT()

        // WHEN
        let result = sut.isBookmarksBarVisible

        // THEN
        XCTAssertFalse(result)
    }

    // MARK: - Selecting a Tab

    // Appearance `showBookmarksBars` false
    @MainActor
    func testWhenSelectedTaContentAndShowBookmarksBarIsFalseThenIsBookmarksBarVisibleIsFalse() throws {
        // GIVEN
        appearance.showBookmarksBar = false

        for content in tabContents {
            var capturedValue: Bool?
            let sut = makeSUT()
            sut.$isBookmarksBarVisible
                .dropFirst() // Not interested in the value when subscribing
                .sink { value in
                    capturedValue = value
                }
                .store(in: &cancellables)

            // WHEN
            selectedTabSubject.send(TabViewModel(tab: Tab(content: content)))

            // THEN
            try assertFalse(capturedValue)
        }
    }

    // Appearance `showBookmarksBars` true and .newTabOnly

    @MainActor
    func testWhenShowBookmarksBarIsTrueAndBookmarkBarAppearanceIsTabOnlyThenIsBookmarksBarVisibleIsTrueForNoneAndNewTab() throws {
        // GIVEN
        appearance.showBookmarksBar = true
        appearance.bookmarksBarAppearance = .newTabOnly

        for content in tabContents {
            var capturedValue: Bool?
            let sut = makeSUT()
            sut.$isBookmarksBarVisible
                .dropFirst() // Not interested in the value when subscribing
                .sink { value in
                    capturedValue = value
                }
                .store(in: &cancellables)

            // WHEN
            selectedTabSubject.send(TabViewModel(tab: Tab(content: content)))

            // THEN
            switch content {
            case .none, .newtab:
                try assertTrue(capturedValue)
            default:
                try assertFalse(capturedValue)
            }
        }
    }

    // Appearance `showBookmarksBars` true and .alwaysOn

    @MainActor
    func testWhenShowBookmarksBarIsTrueAndBookmarkBarAppearanceIsAlwaysOnThenIsBookmarksBarVisibleIsTrue() throws {
        // GIVEN
        appearance.showBookmarksBar = true
        appearance.bookmarksBarAppearance = .alwaysOn

        for content in tabContents {
            var capturedValue: Bool?
            let sut = makeSUT()
            sut.$isBookmarksBarVisible
                .dropFirst() // Not interested in the value when subscribing
                .sink { value in
                    capturedValue = value
                }
                .store(in: &cancellables)

            // WHEN
            selectedTabSubject.send(TabViewModel(tab: Tab(content: content)))

            // THEN
            try assertTrue(capturedValue)
        }
    }

    // MARK: - Settings Change

    @MainActor
    func testWhenChangingShowBookmarksBarToTrueThenIsBookmarksBarVisibleIsTrue() throws {
        // GIVEN
        appearance.showBookmarksBar = false
        appearance.bookmarksBarAppearance = .alwaysOn

        for content in tabContents {
            var capturedValue: Bool?
            let sut = makeSUT()
            XCTAssertFalse(sut.isBookmarksBarVisible)
            sut.$isBookmarksBarVisible
                .dropFirst() // Not interested in the value when subscribing
                .sink { value in
                    capturedValue = value
                }
                .store(in: &cancellables)
            selectedTabSubject.send(TabViewModel(tab: Tab(content: content)))

            // WHEN
            appearance.showBookmarksBar = true

            // THEN
            try assertTrue(capturedValue)
        }
    }

    @MainActor
    func testWhenChangingShowBookmarksBarToFalseThenIsBookmarksBarVisibleIsFalse() throws {
        // GIVEN
        appearance.showBookmarksBar = true
        appearance.bookmarksBarAppearance = .alwaysOn

        for content in tabContents {
            var capturedValue: Bool?
            let sut = makeSUT()
            sut.$isBookmarksBarVisible
                .dropFirst() // Not interested in the value when subscribing
                .sink { value in
                    capturedValue = value
                }
                .store(in: &cancellables)
            selectedTabSubject.send(TabViewModel(tab: Tab(content: content)))

            // WHEN
            appearance.showBookmarksBar = false

            // THEN
            try assertFalse(capturedValue)
        }
    }

    @MainActor
    func testWhenBookmarksBarAppearanceChangesToAlwaysVisibleThenIsBookmarkBarVisibleIsTrue() throws {
        // GIVEN
        appearance.showBookmarksBar = true
        appearance.bookmarksBarAppearance = .newTabOnly

        for content in tabContents {
            var capturedValue: Bool?
            let sut = makeSUT()
            XCTAssertFalse(sut.isBookmarksBarVisible)
            sut.$isBookmarksBarVisible
                .dropFirst() // Not interested in the value when subscribing
                .sink { value in
                    capturedValue = value
                }
                .store(in: &cancellables)
            selectedTabSubject.send(TabViewModel(tab: Tab(content: content)))

            // WHEN
            appearance.bookmarksBarAppearance = .alwaysOn

            // THEN
            try assertTrue(capturedValue)
        }
    }

    @MainActor
    func testWhenBookmarksBarAppearanceChangesToOnlyOnNewTabThenIsBookmarkBarVisibleIsTrueForNoneAndNewTab() throws {
        // GIVEN
        appearance.showBookmarksBar = true
        appearance.bookmarksBarAppearance = .alwaysOn

        for content in tabContents {
            var capturedValue: Bool?
            let sut = makeSUT()
            XCTAssertFalse(sut.isBookmarksBarVisible)
            sut.$isBookmarksBarVisible
                .dropFirst() // Not interested in the value when subscribing
                .sink { value in
                    capturedValue = value
                }
                .store(in: &cancellables)
            selectedTabSubject.send(TabViewModel(tab: Tab(content: content)))

            // WHEN
            appearance.bookmarksBarAppearance = .newTabOnly

            // THEN
            switch content {
            case .none, .newtab:
                try assertTrue(capturedValue)
            default:
                try assertFalse(capturedValue)
            }
        }
    }

    // MARK: - New Tab becoming URL

    @MainActor
    func testWhenBookmarksBarAppeareanceIsNewTabOnlyAndTabContentBecomesURLThenIsBookmarkBarVisibleIsFalse() throws {
        // GIVEN
        appearance.showBookmarksBar = true
        appearance.bookmarksBarAppearance = .newTabOnly
        let sut = makeSUT()
        let tab = Tab(content: .newtab)
        selectedTabSubject.send(TabViewModel(tab: tab))

        var capturedValue: Bool?
        sut.$isBookmarksBarVisible
            .sink { value in
                capturedValue = value
            }
            .store(in: &cancellables)
        try assertTrue(capturedValue)

        // WHEN
        tab.setContent(.url(URL.duckDuckGo, credential: nil, source: .link))

        // THEN
        try assertFalse(capturedValue)
    }

}

private extension BookmarksBarVisibilityManagerTests {

    func assertFalse(_ value: Bool?) throws {
        let value = try XCTUnwrap(value)
        XCTAssertFalse(value)
    }

    func assertTrue(_ value: Bool?) throws {
        let value = try XCTUnwrap(value)
        XCTAssertTrue(value)
    }

}
