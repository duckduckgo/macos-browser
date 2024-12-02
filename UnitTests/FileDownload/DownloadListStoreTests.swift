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
                                                   resumeData: "resumeData".data(using: .utf8)!,
                                                   isRetryable: true)
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

}

private extension DownloadListItem {
    static let testItem = DownloadListItem(identifier: UUID(),
                                           added: Date(),
                                           modified: Date(),
                                           downloadURL: URL(string: "https://duckduckgo.com/testdload")!,
                                           websiteURL: .duckDuckGo,
                                           fileName: "fileName",
                                           progress: nil,
                                           fireWindowSession: nil,
                                           destinationURL: URL(fileURLWithPath: "/test/path"),
                                           destinationFileBookmarkData: nil,
                                           tempURL: URL(fileURLWithPath: "/temp/file/path"),
                                           tempFileBookmarkData: nil,
                                           error: nil)
    static let oldItem = DownloadListItem(identifier: UUID(),
                                          added: .daysAgo(30),
                                          modified: .daysAgo(3),
                                          downloadURL: .duckDuckGo,
                                          websiteURL: .duckDuckGo,
                                          fileName: "fileName",
                                          progress: nil,
                                          fireWindowSession: nil,
                                          destinationURL: URL(fileURLWithPath: "/test/path"),
                                          destinationFileBookmarkData: nil,
                                          tempURL: nil,
                                          tempFileBookmarkData: nil,
                                          error: nil)
    static let olderItem = DownloadListItem(identifier: UUID(),
                                            added: .daysAgo(30),
                                            modified: .daysAgo(1),
                                            downloadURL: URL(string: "https://testdownload.com")!,
                                            websiteURL: nil,
                                            fileName: "fileName",
                                            progress: nil,
                                            fireWindowSession: nil,
                                            destinationURL: URL(fileURLWithPath: "/test/path.jpeg"),
                                            destinationFileBookmarkData: nil,
                                            tempURL: nil,
                                            tempFileBookmarkData: nil,
                                            error: nil)
}
