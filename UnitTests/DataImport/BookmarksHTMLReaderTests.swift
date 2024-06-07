//
//  BookmarksHTMLReaderTests.swift
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

import SnapshotTesting
import XCTest
@testable import DuckDuckGo_Privacy_Browser

final class BookmarksHTMLReaderTests: XCTestCase {

    let bookmarksHTMLReaderTestFilesURL = Bundle(for: BookmarksHTMLReaderTests.self)
        .resourceURL!
        .appendingPathComponent("DataImportResources/TestBookmarksData")

    @MainActor
    func testBookmarksHTMLReaderSnapshot() throws {
        let expectedToThrow: Set<String> = [
            "bookmarks_invalid.html"
        ]

        for fileName in try FileManager.default.contentsOfDirectory(atPath: bookmarksHTMLReaderTestFilesURL.path) {
            let fileNameWithoutExtension = fileName.dropping(suffix: "html")
            let fileURL = bookmarksHTMLReaderTestFilesURL.appendingPathComponent(fileName)
            let reader = BookmarkHTMLReader(bookmarksFileURL: fileURL, otherBookmarksFolderTitle: "Other bookmarks")
            let result = reader.readBookmarks()

            if expectedToThrow.contains(fileName) {
                XCTAssertThrowsError(try result.get(), fileNameWithoutExtension)
                continue
            }
            guard case .success(let importResult) = result else {
                XCTFail("unexpected failure in \(fileNameWithoutExtension): \(result)")
                continue
            }

            assertSnapshot(of: importResult.bookmarks, as: .json, named: fileNameWithoutExtension, testName: "snapshot")
        }
    }

}
