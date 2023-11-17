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

@MainActor
class FirefoxDataImporterTests: XCTestCase {

    func testWhenImportingBookmarks_AndBookmarkImportSucceeds_ThenSummaryIsPopulated() async {
        let loginImporter = MockLoginImporter()
        let faviconManager = FaviconManagerMock()
        let bookmarkImporter = MockBookmarkImporter(importBookmarks: { _, _ in .init(successful: 1, duplicates: 2, failed: 3) })
        let importer = FirefoxDataImporter(profile: .init(browser: .firefox, profileURL: resourceURL()), loginImporter: loginImporter, bookmarkImporter: bookmarkImporter, faviconManager: faviconManager)

        let result = await importer.importData(types: [.bookmarks])

        XCTAssertNil(result.logins)
        if case let .success(bookmarks) = result.bookmarks {
            XCTAssertEqual(bookmarks.successful, 1)
            XCTAssertEqual(bookmarks.duplicates, 2)
            XCTAssertEqual(bookmarks.failed, 3)
        } else {
            XCTFail("Received populated summary unexpectedly")
        }
    }

    private func resourceURL() -> URL {
        let bundle = Bundle(for: FirefoxBookmarksReaderTests.self)
        return bundle.resourceURL!.appendingPathComponent("DataImportResources/TestFirefoxData")
    }
}

extension FirefoxDataImporter {
    func importData(types: Set<DataImport.DataType>) async -> DataImport.Summary {
        return await withCheckedContinuation { continuation in
            importData(types: types) { result in
                continuation.resume(returning: result)
            }
        }
    }
}
