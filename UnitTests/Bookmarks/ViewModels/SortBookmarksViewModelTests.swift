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
import PixelKitTestingUtilities
import Combine
@testable import PixelKit
@testable import DuckDuckGo_Privacy_Browser

class SortBookmarksViewModelTests: XCTestCase {
    let testUserDefault = UserDefaults(suiteName: #function)!
    let manager = MockBookmarkManager()
    let metrics = BookmarksSearchAndSortMetrics()

    func testWhenSortingIsNameAscending_thenSortByNameMetricIsFired() async throws {
        let sut = SortBookmarksViewModel(manager: manager, metrics: metrics, origin: .panel)
        let expectedPixel = GeneralPixel.bookmarksSortByName(origin: "panel")

        try await verify(expectedPixel: expectedPixel, for: { sut.setSort(mode: .nameAscending) })
    }

    func testWhenSortingIsNameDescending_thenSortByNameMetricIsFired() async throws {
        let sut = SortBookmarksViewModel(manager: manager, metrics: metrics, origin: .panel)
        let expectedPixel = GeneralPixel.bookmarksSortByName(origin: "panel")

        try await verify(expectedPixel: expectedPixel, for: { sut.setSort(mode: .nameDescending) })
    }

    func testWhenSortingIsManual_thenSortByNameMetricIsNotFired() async throws {
        let sut = SortBookmarksViewModel(manager: manager, metrics: metrics, origin: .panel)
        let notExpectedPixel = GeneralPixel.bookmarksSortByName(origin: "panel")

        try await verifyNotFired(pixel: notExpectedPixel, for: { sut.setSort(mode: .manual) })
    }

    func testWhenSortingIsManual_thenIsSavedToRepository() {
        let sut = SortBookmarksViewModel(manager: manager, metrics: metrics, origin: .panel)

        sut.setSort(mode: .manual)

        XCTAssertEqual(manager.sortMode, .manual)
    }

    func testWhenSortingIsNameAscending_thenIsSavedToRepository() {
        let sut = SortBookmarksViewModel(manager: manager, metrics: metrics, origin: .panel)

        sut.setSort(mode: .nameAscending)

        XCTAssertEqual(manager.sortMode, .nameAscending)
    }

    func testWhenSortingIsNameDescending_thenIsSavedToRepository() {
        let sut = SortBookmarksViewModel(manager: manager, metrics: metrics, origin: .panel)

        sut.setSort(mode: .nameDescending)

        XCTAssertEqual(manager.sortMode, .nameDescending)
    }

    @MainActor
    func testWhenMenuIsClosedAndNoOptionWasSelected_thenSortButtonDismissedIsFired() async throws {
        let sut = SortBookmarksViewModel(manager: manager, metrics: metrics, origin: .panel)
        let expectedPixel = GeneralPixel.bookmarksSortButtonDismissed(origin: "panel")

        try await verify(expectedPixel: expectedPixel, for: { sut.menuDidClose(NSMenu()) })
    }

    @MainActor
    func testWhenMenuIsClosedAndOptionWasSelected_thenSortButtonDismissedIsNotFired() async throws {
        let sut = SortBookmarksViewModel(manager: manager, metrics: metrics, origin: .panel)
        let notExpectedPixel = GeneralPixel.bookmarksSortButtonDismissed(origin: "panel")

        try await verifyNotFired(pixel: notExpectedPixel, for: {
            sut.setSort(mode: .manual)
            sut.menuDidClose(NSMenu())
        })
    }

    // MARK: - Pixel testing helper methods

    private func verify(expectedPixel: GeneralPixel, for code: () -> Void) async throws {
        let pixelExpectation = expectation(description: "Pixel fired")
        try await verify(pixel: expectedPixel, for: code, expectation: pixelExpectation) {
            await fulfillment(of: [pixelExpectation], timeout: 1.0)
        }
    }

    private func verifyNotFired(pixel: GeneralPixel, for code: () -> Void) async throws {
        let pixelExpectation = expectation(description: "Pixel not fired")
        try await verify(pixel: pixel, for: code, expectation: pixelExpectation) {
            let result = await XCTWaiter().fulfillment(of: [pixelExpectation], timeout: 1)

            if result == .timedOut {
                pixelExpectation.fulfill()
            } else {
                XCTFail("Pixel was fired")
            }
        }
    }

    private func verify(pixel: GeneralPixel,
                        for code: () -> Void,
                        expectation: XCTestExpectation,
                        verification: () async -> Void) async throws {
        let pixelKit = createPixelKit(pixelNamePrefix: pixel.name, pixelExpectation: expectation)

        PixelKit.setSharedForTesting(pixelKit: pixelKit)

        code()
        await verification()

        cleanUp(pixelKit: pixelKit)
    }

    private func createPixelKit(pixelNamePrefix: String, pixelExpectation: XCTestExpectation) -> PixelKit {
        return PixelKit(dryRun: false,
                        appVersion: "1.0.0",
                        defaultHeaders: [:],
                        defaults: testUserDefault) { pixelName, _, _, _, _, _ in
            if pixelName.hasPrefix(pixelNamePrefix) {
                pixelExpectation.fulfill()
            }
        }
    }

    private func cleanUp(pixelKit: PixelKit) {
        PixelKit.tearDown()
        pixelKit.clearFrequencyHistoryForAllPixels()
    }
}
