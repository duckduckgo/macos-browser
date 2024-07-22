//
//  SortBookmarksViewModelTests.swift
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
@testable import DuckDuckGo_Privacy_Browser

final class MockBookmarksMetrics: BookmarksMetricsProtocol {
    var wasSortButtonClickedFired = false
    var wasSortButtonDismissedFired = false
    var wasSortByNameFired = false
    var wasSearchExecutedFired = false
    var wasSearchResultClickedFired = false

    func fireSortButtonClicked(origin: DuckDuckGo_Privacy_Browser.BookmarkOperationOrigin) {
        wasSortButtonClickedFired = true
    }

    func fireSortButtonDismissed(origin: DuckDuckGo_Privacy_Browser.BookmarkOperationOrigin) {
        wasSortButtonDismissedFired = true
    }

    func fireSortByName(origin: DuckDuckGo_Privacy_Browser.BookmarkOperationOrigin) {
        wasSortByNameFired = true
    }

    func fireSearchExecuted(origin: DuckDuckGo_Privacy_Browser.BookmarkOperationOrigin) {
        wasSearchExecutedFired = true
    }

    func fireSearchResultClicked(origin: DuckDuckGo_Privacy_Browser.BookmarkOperationOrigin) {
        wasSearchResultClickedFired = true
    }
}

final class MockSortBookmarksRepository: SortBookmarksRepository {
    var storedSortMode: BookmarksSortMode

    init(storedSortMode: BookmarksSortMode = .manual) {
        self.storedSortMode = storedSortMode
    }
}

class SortBookmarksViewModelTests: XCTestCase {

    let repository = MockSortBookmarksRepository()

    func testWhenSortingIsNameAscending_thenSortByNameMetricIsFired() {
        let metrics = MockBookmarksMetrics()
        let sut = SortBookmarksViewModel(repository: repository, metrics: metrics, origin: .panel)

        sut.setSort(mode: .nameAscending)

        XCTAssertTrue(metrics.wasSortByNameFired)
    }

    func testWhenSortingIsNameDescending_thenSortByNameMetricIsFired() {
        let metrics = MockBookmarksMetrics()
        let sut = SortBookmarksViewModel(repository: repository, metrics: metrics, origin: .panel)

        sut.setSort(mode: .nameDescending)

        XCTAssertTrue(metrics.wasSortByNameFired)
    }

    func testWhenSortingIsManual_thenSortByNameMetricIsNotFired() {
        let metrics = MockBookmarksMetrics()
        let sut = SortBookmarksViewModel(repository: repository, metrics: metrics, origin: .panel)

        sut.setSort(mode: .manual)

        XCTAssertFalse(metrics.wasSortByNameFired)
    }

    func testWhenSortingIsManual_thenIsSavedToRepository() {
        let metrics = MockBookmarksMetrics()
        let sut = SortBookmarksViewModel(repository: repository, metrics: metrics, origin: .panel)

        sut.setSort(mode: .manual)

        XCTAssertEqual(repository.storedSortMode, .manual)
    }

    func testWhenSortingIsNameAscending_thenIsSavedToRepository() {
        let metrics = MockBookmarksMetrics()
        let repository = MockSortBookmarksRepository()
        let sut = SortBookmarksViewModel(repository: repository, metrics: metrics, origin: .panel)

        sut.setSort(mode: .nameAscending)

        XCTAssertEqual(repository.storedSortMode, .nameAscending)
    }

    func testWhenSortingIsNameDescending_thenIsSavedToRepository() {
        let metrics = MockBookmarksMetrics()
        let repository = MockSortBookmarksRepository()
        let sut = SortBookmarksViewModel(repository: repository, metrics: metrics, origin: .panel)

        sut.setSort(mode: .nameDescending)

        XCTAssertEqual(repository.storedSortMode, .nameDescending)
    }

    func testWhenMenuIsClosedAndNoOptionWasSelected_thenSortButtonDismissedIsFired() {
        let metrics = MockBookmarksMetrics()
        let repository = MockSortBookmarksRepository()
        let sut = SortBookmarksViewModel(repository: repository, metrics: metrics, origin: .panel)

        sut.menuDidClose(NSMenu())

        XCTAssertTrue(metrics.wasSortButtonDismissedFired)
    }

    func testWhenMenuIsClosedAndOptionWasSelected_thenSortButtonDismissedIsNotFired() {
        let metrics = MockBookmarksMetrics()
        let repository = MockSortBookmarksRepository()
        let sut = SortBookmarksViewModel(repository: repository, metrics: metrics, origin: .panel)

        sut.setSort(mode: .nameDescending)
        sut.menuDidClose(NSMenu())

        XCTAssertFalse(metrics.wasSortButtonDismissedFired)
    }
}
