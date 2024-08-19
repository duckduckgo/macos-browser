//
//  PasteboardFolderTests.swift
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

class PasteboardFolderTests: XCTestCase {

    func testWhenInitializingPasteboardBookmarkFromValidDictionary_ThenPasteboardBookmarkIsCreated() {
        let uuid = UUID()
        let folder = BookmarkFolder(id: uuid.uuidString, title: "Example")
        let writer = FolderPasteboardWriter(folder: folder)
        let pasteboardFolder = PasteboardFolder(dictionary: writer.internalDictionary)

        XCTAssertNotNil(pasteboardFolder)
        XCTAssertEqual(pasteboardFolder?.id, uuid.uuidString)
        XCTAssertEqual(pasteboardFolder?.name, "Example")
    }

    func testWhenInitializingPasteboardBookmarkFromInvalidDictionary_ThenNilIsReturned() {
        let pasteboardFolder = PasteboardFolder(dictionary: ["some key": "some value"])
        XCTAssertNil(pasteboardFolder)
    }

    func testWhenInitializingPasteboardBookmarkFromValidPasteboardItem_ThenPasteboardBookmarkIsCreated() {
        let folder = BookmarkFolder(id: UUID().uuidString, title: "Example")
        let writer = FolderPasteboardWriter(folder: folder)
        let type = FolderPasteboardWriter.folderUTIInternalType

        let pasteboardItem = NSPasteboardItem(pasteboardPropertyList: writer.internalDictionary, ofType: type)!
        let pasteboardFolder = PasteboardFolder(pasteboardItem: pasteboardItem)

        XCTAssertNotNil(pasteboardFolder)
    }

    func testWhenInitializingPasteboardBookmarkFromInvalidPasteboardItem_ThenNilIsReturned() {
        let type = FolderPasteboardWriter.folderUTIInternalType
        let pasteboardItem = NSPasteboardItem(pasteboardPropertyList: [Any](), ofType: type)!
        let pasteboardFolder = PasteboardFolder(pasteboardItem: pasteboardItem)

        XCTAssertNil(pasteboardFolder)
    }

    func testWhenGettingWritableTypesForBookmarkPasteboardWriter_ThenTypesIncludeInternalBookmarkType() {
        let folder = BookmarkFolder(id: UUID().uuidString, title: "Example")
        let writer = FolderPasteboardWriter(folder: folder)

        let pasteboard = NSPasteboard.test()
        let types = writer.writableTypes(for: pasteboard)
        XCTAssert(types.contains(FolderPasteboardWriter.folderUTIInternalType))
    }

    func testWhenGettingPropertyListForSystemTypes_ThenBookmarkURLIsReturned() {
        let folder = BookmarkFolder(id: UUID().uuidString, title: "Example")
        let writer = FolderPasteboardWriter(folder: folder)

        guard let stringPropertyList = writer.pasteboardPropertyList(forType: .string) as? String else {
            XCTFail("Failed to cast string property list to String")
            return
        }

        XCTAssertEqual(stringPropertyList, "Example")
    }

    func testWhenGettingPropertyListForInternalBookmarkType_ThenBookmarkDictionaryIsReturned() {
        let folder = BookmarkFolder(id: UUID().uuidString, title: "Example")
        let writer = FolderPasteboardWriter(folder: folder)
        let type = FolderPasteboardWriter.folderUTIInternalType

        guard let propertyList = writer.pasteboardPropertyList(forType: type) as? PasteboardAttributes else {
            XCTFail("Failed to cast folder property list to Dictionary")
            return
        }

        XCTAssertEqual(propertyList, writer.internalDictionary)
    }

    func testWhenGettingPropertyListForUnsupportedValue_ThenNilIsReturned() {
        let folder = BookmarkFolder(id: UUID().uuidString, title: "Example")
        let writer = FolderPasteboardWriter(folder: folder)

        // Test a handful of unsupported types to assert that they're nil:
        XCTAssertNil(writer.pasteboardPropertyList(forType: .URL))
        XCTAssertNil(writer.pasteboardPropertyList(forType: .color))
        XCTAssertNil(writer.pasteboardPropertyList(forType: .pdf))
        XCTAssertNil(writer.pasteboardPropertyList(forType: .png))
    }

}
