//
//  FirefoxBookmarksReaderTests.swift
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
import BrowserServicesKit

class FirefoxBookmarksReaderTests: XCTestCase {

    func testImportingBookmarks() {
        let bookmarksReader = FirefoxBookmarksReader(firefoxDataDirectoryURL: resourceURL())
        let bookmarks = bookmarksReader.readBookmarks()

        guard case let .success(bookmarks) = bookmarks else {
            XCTFail("Failed to decode bookmarks")
            return
        }

        XCTAssertEqual(bookmarks.topLevelFolders.bookmarkBar?.type, .folder)
        XCTAssertEqual(bookmarks.topLevelFolders.otherBookmarks?.type, .folder)

        XCTAssertEqual(bookmarks.topLevelFolders.bookmarkBar?.children?.contains(where: { bookmark in
            bookmark.url?.absoluteString == "https://duckduckgo.com/"
        }), true)
    }

    func testFileNotFoundReturnsFailureWithDbOpenError() {
        // Given
        let bookmarksReader = FirefoxBookmarksReader(firefoxDataDirectoryURL: invalidResourceURL())
        let expected: DataImportResult<ImportedBookmarks> = .failure(FirefoxBookmarksReader.ImportError(type: .couldNotFindBookmarksFile, underlyingError: nil))

        // When
        let result = bookmarksReader.readBookmarks()

        // Then
        XCTAssertEqual(expected, result)
    }

    private func resourceURL() -> URL {
        let bundle = Bundle(for: FirefoxBookmarksReaderTests.self)
        return bundle.resourceURL!.appendingPathComponent("DataImportResources/TestFirefoxData")
    }

    private func invalidResourceURL() -> URL {
        let bundle = Bundle(for: FirefoxBookmarksReaderTests.self)
        return bundle.resourceURL!.appendingPathComponent("Nothing/Here")
    }

}
