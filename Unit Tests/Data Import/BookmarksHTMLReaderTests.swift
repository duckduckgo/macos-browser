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

    var testBookmarkFiles: [URL] {
        let bundle = Bundle(for: ChromiumLoginReaderTests.self)
        let directory = bundle.resourceURL!
            .appendingPathComponent("Data Import Resources/Test Bookmarks Data")
        // swiftlint:disable:next force_try
        return try! FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
    }

    func bookmarksFileURL(_ name: String) -> URL {
        let bundle = Bundle(for: ChromiumLoginReaderTests.self)
        return bundle.resourceURL!
            .appendingPathComponent("Data Import Resources/Test Bookmarks Data")
            .appendingPathComponent(name)
    }

    func testExample() throws {

        for bookmarkFile in testBookmarkFiles {
            reader = BookmarkHTMLReader(bookmarksFileURL: bookmarkFile)
            let result = reader.readBookmarks()
            XCTAssertNoThrow(try result.get(), bookmarkFile.absoluteString)
        }
    }

}
