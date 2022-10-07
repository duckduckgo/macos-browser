//
//  FirefoxDataImporterTests.swift
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

import Foundation
import XCTest
@testable import DuckDuckGo_Privacy_Browser

class FirefoxDataImporterTests: XCTestCase {
    
    func testWhenImportingWithoutAnyDataTypes_ThenSummaryIsEmpty() async {
        let loginImporter = MockLoginImporter()
        let faviconManager = FaviconManagerMock()
        let bookmarkImporter = MockBookmarkImporter(importBookmarks: { _, _ in .init(successful: 0, duplicates: 0, failed: 0) })
        let importer = FirefoxDataImporter(loginImporter: loginImporter, bookmarkImporter: bookmarkImporter, faviconManager: faviconManager)
        
        let summary = await importer.importData(types: [], from: .init(profileURL: resourceURL()))
        
        if case let .success(summary) = summary {
            XCTAssert(summary.isEmpty)
        } else {
            XCTFail("Received failure unexpectedly")
        }
    }
    
    func testWhenImportingBookmarks_AndBookmarkImportSucceeds_ThenSummaryIsPopulated() async {
        let loginImporter = MockLoginImporter()
        let faviconManager = FaviconManagerMock()
        let bookmarkImporter = MockBookmarkImporter(importBookmarks: { _, _ in .init(successful: 1, duplicates: 2, failed: 3) })
        let importer = FirefoxDataImporter(loginImporter: loginImporter, bookmarkImporter: bookmarkImporter, faviconManager: faviconManager)
        
        let summary = await importer.importData(types: [.bookmarks], from: .init(profileURL: resourceURL()))
        
        if case let .success(summary) = summary {
            XCTAssertEqual(summary.bookmarksResult?.successful, 1)
            XCTAssertEqual(summary.bookmarksResult?.duplicates, 2)
            XCTAssertEqual(summary.bookmarksResult?.failed, 3)
            XCTAssertNil(summary.loginsResult)
        } else {
            XCTFail("Received populated summary unexpectedly")
        }
    }

    func testWhenImportingBookmarks_AndBookmarkImportFails_ThenErrorIsReturned() async {
        let loginImporter = MockLoginImporter()
        let faviconManager = FaviconManagerMock()
        let bookmarkImporter = MockBookmarkImporter(throwableError: DataImportError.bookmarks(.cannotAccessCoreData),
                                                    importBookmarks: { _, _ in .init(successful: 0, duplicates: 0, failed: 0) })
        let importer = FirefoxDataImporter(loginImporter: loginImporter, bookmarkImporter: bookmarkImporter, faviconManager: faviconManager)
        
        let summary = await importer.importData(types: [.bookmarks], from: .init(profileURL: resourceURL()))
        
        if case let .failure(error) = summary {
            XCTAssertEqual(error, .bookmarks(.cannotReadFile))
        } else {
            XCTFail("Received summary unexpectedly")
        }
    }
    
    private func resourceURL() -> URL {
        let bundle = Bundle(for: FirefoxBookmarksReaderTests.self)
        return bundle.resourceURL!.appendingPathComponent("Data Import Resources/Test Firefox Data")
    }
}
