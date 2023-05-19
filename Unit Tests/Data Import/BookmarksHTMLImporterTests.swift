//
//  BookmarksHTMLImporterTests.swift
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

import XCTest
@testable import DuckDuckGo_Privacy_Browser

final class BookmarksHTMLImporterTests: XCTestCase {

    var dataImporter: BookmarkHTMLImporter!
    var underlyingBookmarkImporter: MockBookmarkImporter!

    override func setUpWithError() throws {
        underlyingBookmarkImporter = MockBookmarkImporter(importBookmarks: { _, _ in
                .init(successful: 0, duplicates: 0, failed: 0)
        })
    }

    func bookmarksFileURL(_ name: String) -> URL {
        let bundle = Bundle(for: ChromiumLoginReaderTests.self)
        return bundle.resourceURL!
            .appendingPathComponent("Data Import Resources/Test Bookmarks Data")
            .appendingPathComponent(name)
    }

    func testWhenValidBookmarksFileIsLoadedThenCorrectBookmarksCountIsReturned() {
        dataImporter = .init(fileURL: bookmarksFileURL("bookmarks_safari.html"), bookmarkImporter: underlyingBookmarkImporter)
        XCTAssertEqual(dataImporter.totalBookmarks, 14)
    }

    func testWhenInvalidBookmarksFileIsLoadedThenBookmarksCountIsZero() {
        dataImporter = .init(fileURL: bookmarksFileURL("bookmarks_invalid.html"), bookmarkImporter: underlyingBookmarkImporter)
        XCTAssertEqual(dataImporter.totalBookmarks, 0)
    }

    func testWhenValidBookmarksFileIsLoadedThenBookmarksImportIsSuccessful() {
        let importExpectation = expectation(description: "Import Bookmarks")
        let completionExpectation = expectation(description: "Import Bookmarks Completion")
        let expectedImportResult = BookmarkImportResult(successful: 0, duplicates: 0, failed: 0)

        underlyingBookmarkImporter.importBookmarks = { (_, _) in
            importExpectation.fulfill()
            return expectedImportResult
        }

        dataImporter = .init(fileURL: bookmarksFileURL("bookmarks_safari.html"), bookmarkImporter: underlyingBookmarkImporter)

        dataImporter.importData(types: [.bookmarks], from: nil) { result in
            switch result {
            case let .success(summary):
                XCTAssertEqual(summary, .init(bookmarksResult: expectedImportResult))
            default:
                XCTFail("unexpected import error")
            }
            completionExpectation.fulfill()
        }

        waitForExpectations(timeout: 1)
    }

    func testWhenValidBookmarksFileIsLoadedButImporterThrowsAnErrorThenBookmarksImportReturnsFailure() {
        let completionExpectation = expectation(description: "Import Bookmarks Completion")

        underlyingBookmarkImporter.throwableError = BookmarkImportErrorMock()

        dataImporter = .init(fileURL: bookmarksFileURL("bookmarks_safari.html"), bookmarkImporter: underlyingBookmarkImporter)

        dataImporter.importData(types: [.bookmarks], from: nil) { result in
            switch result {
            case .success:
                XCTFail("unexpected import success")
            case let .failure(error):
                XCTAssertEqual(error.errorType, .cannotAccessCoreData)
            }
            completionExpectation.fulfill()
        }

        waitForExpectations(timeout: 1)
    }

    func testWhenInvalidBookmarksFileIsLoadedThenBookmarksImportReturnsFailure() {
        let completionExpectation = expectation(description: "Import Bookmarks Completion")
        let expectedImportResult = BookmarkImportResult(successful: 0, duplicates: 0, failed: 0)

        underlyingBookmarkImporter.importBookmarks = { (_, _) in
            XCTFail("unexpected import success")
            return expectedImportResult
        }

        dataImporter = .init(fileURL: bookmarksFileURL("bookmarks_invalid.html"), bookmarkImporter: underlyingBookmarkImporter)

        dataImporter.importData(types: [.bookmarks], from: nil) { result in
            switch result {
            case .success:
                XCTFail("unexpected import success")
            case let .failure(error):
                XCTAssertEqual(error.errorType, .cannotReadFile)
            }
            completionExpectation.fulfill()
        }

        waitForExpectations(timeout: 1)
    }
}
