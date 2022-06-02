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

import XCTest
@testable import DuckDuckGo_Privacy_Browser

class BookmarksHTMLReaderTests: XCTestCase {

    var reader: BookmarkHTMLReader!

    func bookmarksFileURL(_ name: String) -> URL {
        let bundle = Bundle(for: ChromiumLoginReaderTests.self)
        return bundle.resourceURL!
            .appendingPathComponent("Data Import Resources/Test Bookmarks Data")
            .appendingPathComponent(name)
    }

    func test_WhenParseChromeHtml_ThenImportSuccess() throws {
        reader = BookmarkHTMLReader(bookmarksFileURL: bookmarksFileURL("bookmarks_chrome.html"))
        let result = reader.readBookmarks()

        let importedBookmarks = try XCTUnwrap(try? result.get())
        XCTAssertEqual(importedBookmarks.bookmarks.numberOfBookmarks, 12)
    }

    func test_WhenParseSafariHtml_ThenImportSuccess() throws {
        reader = BookmarkHTMLReader(bookmarksFileURL: bookmarksFileURL("bookmarks_safari.html"))
        let result = reader.readBookmarks()

        let importedBookmarks = try XCTUnwrap(try? result.get())
        XCTAssertEqual(importedBookmarks.bookmarks.numberOfBookmarks, 14)
    }

    func test_WhenParseFirefoxHtml_ThenImportSuccess() throws {
        reader = BookmarkHTMLReader(bookmarksFileURL: bookmarksFileURL("bookmarks_firefox.html"))
        let result = reader.readBookmarks()

        let importedBookmarks = try XCTUnwrap(try? result.get())
        XCTAssertEqual(importedBookmarks.bookmarks.numberOfBookmarks, 17)
    }

    func test_WhenParseBraveHtml_ThenImportSuccess() throws {
        reader = BookmarkHTMLReader(bookmarksFileURL: bookmarksFileURL("bookmarks_brave.html"))
        let result = reader.readBookmarks()

        let importedBookmarks = try XCTUnwrap(try? result.get())
        XCTAssertEqual(importedBookmarks.bookmarks.numberOfBookmarks, 12)
    }

    func test_WhenParseDDGAndroidHtml_ThenImportSuccess() throws {
        reader = BookmarkHTMLReader(bookmarksFileURL: bookmarksFileURL("bookmarks_ddg_android.html"))
        let result = reader.readBookmarks()

        let importedBookmarks = try XCTUnwrap(try? result.get())
        XCTAssertEqual(importedBookmarks.bookmarks.numberOfBookmarks, 13)
    }

    func test_WhenParseDDGiOSHtml_ThenImportSuccess() throws {
        reader = BookmarkHTMLReader(bookmarksFileURL: bookmarksFileURL("bookmarks_ddg_ios.html"))
        let result = reader.readBookmarks()

        let importedBookmarks = try XCTUnwrap(try? result.get())
        XCTAssertEqual(importedBookmarks.bookmarks.numberOfBookmarks, 8)
    }

    func test_WhenParseDDGMacOSHtml_ThenImportSuccess() throws {
        reader = BookmarkHTMLReader(bookmarksFileURL: bookmarksFileURL("bookmarks_ddg_macos.html"))
        let result = reader.readBookmarks()

        let importedBookmarks = try XCTUnwrap(try? result.get())
        XCTAssertEqual(importedBookmarks.bookmarks.numberOfBookmarks, 13)
    }

    func test_WhenParseInvalidHtml_ThenImportFail() throws {
        reader = BookmarkHTMLReader(bookmarksFileURL: bookmarksFileURL("bookmarks_invalid.html"))
        let result = reader.readBookmarks()

        XCTAssertThrowsError(try result.get(), "", { error in
            guard case BookmarkHTMLReader.ImportError.unexpectedBookmarksFileFormat = error else {
                XCTFail("Unexpected error type: \(String(reflecting: error))")
                return
            }
        })
    }
}
