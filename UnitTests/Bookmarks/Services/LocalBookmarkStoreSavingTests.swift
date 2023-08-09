//
//  LocalBookmarkStoreSavingTests.swift
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

import Foundation
import Bookmarks
import XCTest
import CoreData
@testable import DuckDuckGo_Privacy_Browser

final class LocalBookmarkStoreSavingTests: XCTestCase {

    enum LocalError: Error {
        case example
    }

    // MARK: Save/Delete

    let container = CoreData.bookmarkContainer()
    var store: LocalBookmarkStore!

    override func setUp() {
        super.setUp()

        BookmarkUtils.prepareFoldersStructure(in: container.viewContext)

        do {
            try container.viewContext.save()
        } catch {
            XCTFail("Could not prepare Bookmarks Structure")
        }

        store = LocalBookmarkStore {
            self.container.newBackgroundContext()
        }
    }

    func testWhenThereIsNoErrorThenDataIsSaved() throws {
        let otherContext = container.newBackgroundContext()

        try store.applyChangesAndSave { context in
            let root = BookmarkUtils.fetchRootFolder(context)
            _ = BookmarkEntity.makeBookmark(title: "T", url: "h", parent: root!, context: context)
        }

        otherContext.performAndWait {
            let root = BookmarkUtils.fetchRootFolder(otherContext)
            XCTAssertEqual(root?.childrenArray.first?.title, "T")
            XCTAssertEqual(root?.childrenArray.first?.url, "h")
        }
    }

    func testWhenThereIsNoErrorThenDataIsSaved_Closures() throws {
        let otherContext = container.newBackgroundContext()

        let expectation = expectation(description: "Did save")

        store.applyChangesAndSave { context in
            let root = BookmarkUtils.fetchRootFolder(context)
            _ = BookmarkEntity.makeBookmark(title: "T", url: "h", parent: root!, context: context)
        } onError: { _ in
            XCTFail("Error not expected")
        } onDidSave: {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5)

        otherContext.performAndWait {
            let root = BookmarkUtils.fetchRootFolder(otherContext)
            XCTAssertEqual(root?.childrenArray.first?.title, "T")
            XCTAssertEqual(root?.childrenArray.first?.url, "h")
        }
    }

    func testWhenThereIsExplicitErrorThenOnErrorIsCalled() {
        let otherContext = container.newBackgroundContext()

        do {
            try store.applyChangesAndSave { context in
                let root = BookmarkUtils.fetchRootFolder(context)
                _ = BookmarkEntity.makeBookmark(title: "T", url: "h", parent: root!, context: context)

                throw LocalError.example
            }
            XCTFail("Exception should be thrown")
        } catch {
            XCTAssertEqual(error as? LocalError, .example)
        }

        otherContext.performAndWait {
            let root = BookmarkUtils.fetchRootFolder(otherContext)
            XCTAssert(root!.childrenArray.isEmpty)
        }
    }

    func testWhenThereIsExplicitErrorThenOnErrorIsCalled_Closures() {
        let otherContext = container.newBackgroundContext()

        let expectation = expectation(description: "OnError")

        store.applyChangesAndSave { context in
            let root = BookmarkUtils.fetchRootFolder(context)
            _ = BookmarkEntity.makeBookmark(title: "T", url: "h", parent: root!, context: context)

            throw LocalError.example
        } onError: { error in
            expectation.fulfill()
            XCTAssertEqual(error as? LocalError, .example)
        } onDidSave: {
            XCTFail("Should not save")
        }

        wait(for: [expectation], timeout: 5)

        otherContext.performAndWait {
            let root = BookmarkUtils.fetchRootFolder(otherContext)
            XCTAssert(root!.childrenArray.isEmpty)
        }
    }

    func testWhenThereIsSaveErrorThenOnErrorIsCalled() {
        let otherContext = container.newBackgroundContext()

        do {
            try store.applyChangesAndSave { context in
                let root = BookmarkUtils.fetchRootFolder(context)
                let folder = BookmarkEntity.makeFolder(title: "Folder", parent: root!, context: context)
                folder.url = "incorrect value"
            }
            XCTFail("Exception should be thrown")
        } catch {
            XCTAssertEqual(error as? BookmarkEntity.Error, BookmarkEntity.Error.folderHasURL)
        }

        otherContext.performAndWait {
            let root = BookmarkUtils.fetchRootFolder(otherContext)
            XCTAssert(root!.childrenArray.isEmpty)
        }
    }

    func testWhenThereIsSaveErrorThenOnErrorIsCalled_Closures() {
        let otherContext = container.newBackgroundContext()

        let expectation = expectation(description: "OnError")

        store.applyChangesAndSave { context in
            let root = BookmarkUtils.fetchRootFolder(context)
            let folder = BookmarkEntity.makeFolder(title: "Folder", parent: root!, context: context)
            folder.url = "incorrect value"
        } onError: { error in
            expectation.fulfill()
            XCTAssertEqual(error as? BookmarkEntity.Error, BookmarkEntity.Error.folderHasURL)
        } onDidSave: {
            XCTFail("Should not save")
        }

        wait(for: [expectation], timeout: 5)

        otherContext.performAndWait {
            let root = BookmarkUtils.fetchRootFolder(otherContext)
            XCTAssert(root!.childrenArray.isEmpty)
        }
    }

    func testWhenThereIsMergeErrorThenSaveRetries() {

        let otherContext = container.newBackgroundContext()

        do {
            try store.applyChangesAndSave { context in
                let root = BookmarkUtils.fetchRootFolder(context)
                _ = BookmarkEntity.makeBookmark(title: "T", url: "h", parent: root!, context: context)

                otherContext.performAndWait {
                    let root = BookmarkUtils.fetchRootFolder(otherContext)

                    // Only store on first pass
                    guard root?.childrenArray.isEmpty ?? false else { return }

                    _ = BookmarkEntity.makeBookmark(title: "Inner", url: "i", parent: root!, context: otherContext)
                    do {
                        try otherContext.save()
                    } catch {
                        XCTFail("Could not save inner object")
                    }
                }
            }
        } catch {
            XCTFail("Exception should not be thrown")
        }

        otherContext.performAndWait {
            otherContext.reset()
            let root = BookmarkUtils.fetchRootFolder(otherContext)
            let children = root?.childrenArray ?? []

            XCTAssertEqual(children.count, 2)
            XCTAssertEqual(Set(children.map { $0.title }), ["T", "Inner"])
        }
    }

    func testWhenThereIsMergeErrorThenSaveRetries_Closures() {

        let otherContext = container.newBackgroundContext()

        let expectation = expectation(description: "On DidSave")

        store.applyChangesAndSave { context in
            let root = BookmarkUtils.fetchRootFolder(context)
            _ = BookmarkEntity.makeBookmark(title: "T", url: "h", parent: root!, context: context)

            otherContext.performAndWait {
                let root = BookmarkUtils.fetchRootFolder(otherContext)

                // Only store on first pass
                guard root?.childrenArray.isEmpty ?? false else { return }

                _ = BookmarkEntity.makeBookmark(title: "Inner", url: "i", parent: root!, context: otherContext)
                do {
                    try otherContext.save()
                } catch {
                    XCTFail("Could not save inner object")
                }
            }
        } onError: { _ in
            XCTFail("No error expected")
        } onDidSave: {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5)

        otherContext.performAndWait {
            otherContext.reset()
            let root = BookmarkUtils.fetchRootFolder(otherContext)
            let children = root?.childrenArray ?? []

            XCTAssertEqual(children.count, 2)
            XCTAssertEqual(Set(children.map { $0.title }), ["T", "Inner"])
        }
    }

    func testWhenThereIsRecurringMergeErrorThenOnErrorIsCalled() {
        let otherContext = container.newBackgroundContext()

        do {
            try store.applyChangesAndSave { context in
                let root = BookmarkUtils.fetchRootFolder(context)
                _ = BookmarkEntity.makeBookmark(title: "T", url: "h", parent: root!, context: context)

                otherContext.performAndWait {
                    let root = BookmarkUtils.fetchRootFolder(otherContext)
                    _ = BookmarkEntity.makeBookmark(title: "Inner", url: "i", parent: root!, context: otherContext)
                    do {
                        try otherContext.save()
                    } catch {
                        XCTFail("Could not save inner object")
                    }
                }
            }
            XCTFail("Should trow an error")
        } catch {
            if case LocalBookmarkStore.BookmarkStoreError.saveLoopError(let wrappedError) = error, let wrappedError {
                XCTAssertEqual((wrappedError as NSError).code, NSManagedObjectMergeError)
            } else {
                XCTFail("Loop Error expected")
            }
        }

        otherContext.performAndWait {
            otherContext.reset()
            let root = BookmarkUtils.fetchRootFolder(otherContext)
            let children = root?.childrenArray ?? []

            XCTAssertEqual(children.count, 4)
            XCTAssertEqual(Set(children.map { $0.title }), ["Inner"])
        }
    }

    func testWhenThereIsRecurringMergeErrorThenOnErrorIsCalled_Closures() {
        let otherContext = container.newBackgroundContext()

        let expectation = expectation(description: "OnError")

        store.applyChangesAndSave { context in
            let root = BookmarkUtils.fetchRootFolder(context)
            _ = BookmarkEntity.makeBookmark(title: "T", url: "h", parent: root!, context: context)

            otherContext.performAndWait {
                let root = BookmarkUtils.fetchRootFolder(otherContext)
                _ = BookmarkEntity.makeBookmark(title: "Inner", url: "i", parent: root!, context: otherContext)
                do {
                    try otherContext.save()
                } catch {
                    XCTFail("Could not save inner object")
                }
            }
        } onError: { error in
            expectation.fulfill()

            if case LocalBookmarkStore.BookmarkStoreError.saveLoopError(let wrappedError) = error, let wrappedError {
                XCTAssertEqual((wrappedError as NSError).code, NSManagedObjectMergeError)
            } else {
                XCTFail("Loop Error expected")
            }
        } onDidSave: {
            XCTFail("Did save should not be called")
        }

        wait(for: [expectation], timeout: 5)

        otherContext.performAndWait {
            otherContext.reset()
            let root = BookmarkUtils.fetchRootFolder(otherContext)
            let children = root?.childrenArray ?? []

            XCTAssertEqual(children.count, 4)
            XCTAssertEqual(Set(children.map { $0.title }), ["Inner"])
        }
    }

}
