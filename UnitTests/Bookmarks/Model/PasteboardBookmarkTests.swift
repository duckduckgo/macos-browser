//
//  PasteboardBookmarkTests.swift
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

import XCTest
@testable import DuckDuckGo_Privacy_Browser

class PasteboardBookmarkTests: XCTestCase {

    func testWhenInitializingPasteboardBookmarkFromValidDictionary_ThenPasteboardBookmarkIsCreated() {
        let uuid = UUID().uuidString
        let bookmark = Bookmark(id: uuid, url: "https://example.com", title: "Example", isFavorite: false)
        let writer = BookmarkPasteboardWriter(bookmark: bookmark)
        let pasteboardBookmark = PasteboardBookmark(dictionary: writer.internalDictionary)

        XCTAssertNotNil(pasteboardBookmark)
        XCTAssertEqual(pasteboardBookmark?.id, uuid)
        XCTAssertEqual(pasteboardBookmark?.url, "https://example.com")
        XCTAssertEqual(pasteboardBookmark?.title, "Example")
    }

    func testWhenInitializingPasteboardBookmarkFromValidPasteboardItem_ThenPasteboardBookmarkIsCreated() {
        let bookmark = Bookmark(id: UUID().uuidString, url: "https://example.com", title: "Example", isFavorite: false)
        let writer = BookmarkPasteboardWriter(bookmark: bookmark)
        let type = BookmarkPasteboardWriter.bookmarkUTIInternalType

        let pasteboardItem = NSPasteboardItem(pasteboardPropertyList: writer.internalDictionary, ofType: type)!
        let pasteboardBookmark = PasteboardBookmark(pasteboardItem: pasteboardItem)

        XCTAssertNotNil(pasteboardBookmark)
    }

    func testWhenGettingWritableTypesForBookmarkPasteboardWriter_ThenTypesIncludeInternalBookmarkType() {
        let bookmark = Bookmark(id: UUID().uuidString, url: "https://example.com", title: "Example", isFavorite: false)
        let writer = BookmarkPasteboardWriter(bookmark: bookmark)

        let pasteboard = NSPasteboard.test()
        let types = writer.writableTypes(for: pasteboard)
        XCTAssert(types.contains(BookmarkPasteboardWriter.bookmarkUTIInternalType))
    }

    func testWhenGettingPropertyListForSystemTypes_ThenBookmarkURLIsReturned() {
        let bookmark = Bookmark(id: UUID().uuidString, url: "https://example.com", title: "Example", isFavorite: false)
        let writer = BookmarkPasteboardWriter(bookmark: bookmark)

        guard let stringPropertyList = writer.pasteboardPropertyList(forType: .string) as? String else {
            XCTFail("Failed to cast string property list to String")
            return
        }

        XCTAssertEqual(stringPropertyList, "https://example.com")

        guard let urlPropertyList = writer.pasteboardPropertyList(forType: .URL) as? String else {
            XCTFail("Failed to cast URL property list to String")
            return
        }

        XCTAssertEqual(urlPropertyList, "https://example.com")
    }

    func testWhenGettingPropertyListForInternalBookmarkType_ThenBookmarkDictionaryIsReturned() {
        let bookmark = Bookmark(id: UUID().uuidString, url: "https://example.com", title: "Example", isFavorite: false)
        let writer = BookmarkPasteboardWriter(bookmark: bookmark)
        let type = BookmarkPasteboardWriter.bookmarkUTIInternalType

        guard let propertyList = writer.pasteboardPropertyList(forType: type) as? PasteboardAttributes else {
            XCTFail("Failed to cast bookmark property list to Dictionary")
            return
        }

        XCTAssertEqual(propertyList, writer.internalDictionary)
    }

    func testWhenGettingPropertyListForUnsupportedValue_ThenNilIsReturned() {
        let bookmark = Bookmark(id: UUID().uuidString, url: "https://example.com", title: "Example", isFavorite: false)
        let writer = BookmarkPasteboardWriter(bookmark: bookmark)

        // Test a handful of unsupported types to assert that they're nil:
        XCTAssertNil(writer.pasteboardPropertyList(forType: .color))
        XCTAssertNil(writer.pasteboardPropertyList(forType: .pdf))
        XCTAssertNil(writer.pasteboardPropertyList(forType: .png))
    }

}
