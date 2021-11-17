//
//  BookmarksExporterTests.swift
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

class BookmarksExporterTests: XCTestCase {

    struct TestData {
        static let exampleUrl = URL(string: "https://example.com")!
        static let exampleTitle = "Example"

        static let otherUrl = URL(string: "https://other.com")!
        static let otherTitle = "Other"
    }

    let tmpFile: URL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".html", isDirectory: false)

    func test_WhenMultipleBookmarksAtTopLevel_ThenFileContainsAllBookmarksAtTopLevel() throws {
        let exporter = BookmarksExporter(list: BookmarkList(entities: [], topLevelEntities: [
            Bookmark.init(id: UUID(), url: TestData.exampleUrl, title: TestData.exampleTitle, isFavorite: false),
            Bookmark.init(id: UUID(), url: TestData.otherUrl, title: TestData.otherTitle, isFavorite: false)
        ]))

        try exporter.exportBookmarksTo(url: tmpFile)
        assertExportedFileEquals([
            BookmarksExporter.Template.header,
            BookmarksExporter.Template.bookmark(title: TestData.exampleTitle, url: TestData.exampleUrl),
            BookmarksExporter.Template.bookmark(title: TestData.otherTitle, url: TestData.otherUrl),
            BookmarksExporter.Template.footer
        ].joined())
    }

    func test_WhenBookmarkAtTopLevel_ThenFileContainsBookmarkAtTopLevel() throws {
        let exporter = BookmarksExporter(list: BookmarkList(entities: [], topLevelEntities: [
            Bookmark.init(id: UUID(), url: TestData.exampleUrl, title: TestData.exampleTitle, isFavorite: false)
        ]))

        try exporter.exportBookmarksTo(url: tmpFile)
        assertExportedFileEquals([
            BookmarksExporter.Template.header,
            BookmarksExporter.Template.bookmark(title: TestData.exampleTitle, url: TestData.exampleUrl),
            BookmarksExporter.Template.footer
        ].joined())
    }

    func test_WhenNoBookmarks_ThenFileContainsOnlyHeaderAndFooter() throws {
        let exporter = BookmarksExporter(list: BookmarkList(entities: [], topLevelEntities: []))
        try exporter.exportBookmarksTo(url: tmpFile)
        assertExportedFileEquals([
            BookmarksExporter.Template.header,
            BookmarksExporter.Template.footer
        ].joined())
    }

    private func assertExportedFileEquals(_ expected: String) {
        print(tmpFile.absoluteString)
        let actual = try? String(contentsOf: tmpFile)
        XCTAssertEqual(expected, actual)
    }

}
