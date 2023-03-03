//
//  DownloadListStoreTests.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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

import Foundation
import XCTest
@testable import DuckDuckGo_Privacy_Browser

final class DownloadListStoreTests: XCTestCase {

    let container = CoreData.downloadsContainer()
    lazy var store = DownloadListStore(context: container.viewContext)

    func save(_ item: DownloadListItem, expectation: XCTestExpectation) {
        store.save(item) { error in
            expectation.fulfill()
            XCTAssertNil(error)
        }
    }

    func testWhenDownloadItemIsSavedMultipleTimes_ThenTheNewestValueMustBeLoadedFromStore() {
        var item = DownloadListItem.testItem
        let firstSavingExpectation = self.expectation(description: "Saving")
        save(item, expectation: firstSavingExpectation)

        item.destinationURL = URL(fileURLWithPath: "/new/path")
        item.error = .failedToCompleteDownloadTask(underlyingError: NSError(domain: "test",
                                                                            code: 42,
                                                                            userInfo: [NSLocalizedDescriptionKey: "localized description"]),
                                                   resumeData: "resumeData".data(using: .utf8)!)
        let secondSavingExpectation = self.expectation(description: "Saving")
        save(item, expectation: secondSavingExpectation)

        let loadingExpectation = self.expectation(description: "Loading")
        store.fetch { result in
            loadingExpectation.fulfill()
            guard case .success(let items) = result else { XCTFail("unexpected failure \(result)"); return }
            XCTAssertEqual(items, [item])
        }

        waitForExpectations(timeout: 1, handler: nil)
    }

    func testWhenSyncIsCalledThenItemsAreSavedSynchronously() throws {
        store.save(.testItem)
        store.sync()

        let items = try container.viewContext.fetch(DownloadManagedObject.fetchRequest() as NSFetchRequest<DownloadManagedObject>)
        XCTAssertEqual(items.count, 1)
    }

    func testWhenFetchClearingItemsOlderThanIsCalled_ThenOlderItemsThanDateAreCleaned() {
        let oldItem = DownloadListItem(identifier: UUID(),
                                       added: Date.daysAgo(30),
                                       modified: Date.daysAgo(3),
                                       url: URL(string: "https://duckduckgo.com")!,
                                       websiteURL: nil,
                                       progress: nil,
                                       fileType: .pdf,
                                       destinationURL: URL(fileURLWithPath: "/test/path"),
                                       tempURL: nil,
                                       error: nil)
        let notSoOldItem = DownloadListItem.olderItem
        let newItem = DownloadListItem.testItem

        save(oldItem, expectation: self.expectation(description: "Saving 1"))
        save(notSoOldItem, expectation: self.expectation(description: "Saving 2"))
        save(newItem, expectation: self.expectation(description: "Saving 3"))

        let loadingExpectation = self.expectation(description: "Loading")
        store.fetch(clearingItemsOlderThan: Date.daysAgo(2)) { result in
            loadingExpectation.fulfill()
            guard case .success(let items) = result else { XCTFail("unexpected failure \(result)"); return }

            XCTAssertEqual(items.count, 2)
            XCTAssertTrue(items.contains(notSoOldItem))
            XCTAssertTrue(items.contains(newItem))
        }

        waitForExpectations(timeout: 1, handler: nil)
    }

    func testWhenDownloadIsRemoved_ThenItShouldntBeLoadedFromStore() throws {
        let item1 = DownloadListItem.testItem
        let item2 = DownloadListItem.olderItem
        save(item1, expectation: self.expectation(description: "Saving 1"))
        save(item2, expectation: self.expectation(description: "Saving 2"))

        store.remove(item1)

        let loadingExpectation = self.expectation(description: "Loading")
        store.fetch { result in
            loadingExpectation.fulfill()
            guard case .success(let items) = result else { XCTFail("unexpected failure \(result)"); return }

            XCTAssertEqual(items, [item2])
        }

        waitForExpectations(timeout: 1)
    }

    func testWhenDownloadsCleared_ThenNoItemsLoaded() throws {
        save(.testItem, expectation: self.expectation(description: "Saving 1"))
        save(.olderItem, expectation: self.expectation(description: "Saving 2"))

        store.clear()

        let loadingExpectation = self.expectation(description: "Loading")
        store.fetch { result in
            loadingExpectation.fulfill()
            guard case .success(let items) = result else { XCTFail("unexpected failure \(result)"); return }

            XCTAssertEqual(items, [])
        }

        waitForExpectations(timeout: 1)
    }

}

extension DownloadListItem {
    static let testItem = DownloadListItem(identifier: UUID(),
                                           added: Date(),
                                           modified: Date(),
                                           url: URL(string: "https://duckduckgo.com/testdload")!,
                                           websiteURL: URL(string: "https://duckduckgo.com"),
                                           progress: nil,
                                           fileType: .pdf,
                                           destinationURL: URL(fileURLWithPath: "/test/file/path"),
                                           tempURL: URL(fileURLWithPath: "/temp/file/path"),
                                           error: nil)
    static let olderItem = DownloadListItem(identifier: UUID(),
                                            added: Date.daysAgo(30),
                                            modified: Date.daysAgo(1),
                                            url: URL(string: "https://testdownload.com")!,
                                            websiteURL: nil,
                                            progress: nil,
                                            fileType: .jpeg,
                                            destinationURL: URL(fileURLWithPath: "/test/path.jpeg"),
                                            tempURL: nil,
                                            error: nil)
}
