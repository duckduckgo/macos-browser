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
            .appendingPathComponent("DataImportResources/TestBookmarksData")
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

    func testWhenValidBookmarksFileIsLoadedThenBookmarksImportIsSuccessful() async {
        underlyingBookmarkImporter.importBookmarks = { (_, _) in
            .init(successful: 42, duplicates: 2, failed: 3)
        }

        dataImporter = .init(fileURL: bookmarksFileURL("bookmarks_safari.html"), bookmarkImporter: underlyingBookmarkImporter)

        let result = await dataImporter.importData(types: [.bookmarks]).task.value

        XCTAssertEqual(result, [.bookmarks: .success(.init(successful: 42, duplicate: 2, failed: 3))])
    }

    func testWhenInvalidBookmarksFileIsLoadedThenBookmarksImportReturnsFailure() async {
        underlyingBookmarkImporter.importBookmarks = { (_, _) in
            .init(successful: 0, duplicates: 0, failed: 0)
        }

        dataImporter = .init(fileURL: bookmarksFileURL("bookmarks_invalid.html"), bookmarkImporter: underlyingBookmarkImporter)

        let result = await dataImporter.importData(types: [.bookmarks]).task.value

        XCTAssertEqual(result, [.bookmarks: .failure(BookmarkHTMLReader.ImportError(type: .parseXml, underlyingError: NSError(domain: XMLParser.errorDomain, code: XMLParser.ErrorCode.prematureDocumentEndError.rawValue)))])
    }

}
