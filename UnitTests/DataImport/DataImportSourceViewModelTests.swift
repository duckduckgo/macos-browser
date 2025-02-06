//
//  DataImportSourceViewModelTests.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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

final class DataImportSourceViewModelTests: XCTestCase {

    func testImportSourcesContainsMandatorySources() {
        let model = DataImportSourceViewModel(selectedSource: .csv)

        XCTAssertEqual(model.importSources.compactMap { $0 }, DataImport.Source.allCases.filter(\.canImportData))

        XCTAssertTrue(model.importSources.contains(.safari))
        XCTAssertTrue(model.importSources.contains(.bitwarden))
        XCTAssertTrue(model.importSources.contains(.onePassword8))
        XCTAssertTrue(model.importSources.contains(.lastPass))
        XCTAssertTrue(model.importSources.contains(.csv))
        XCTAssertTrue(model.importSources.contains(.bookmarksHTML))

        XCTAssertEqual(model.selectedSourceIndex, model.importSources.firstIndex(of: .csv))
    }

    func testSeparatorsBeforeOnePasswordAndCSVImportArePresent() {
        let model = DataImportSourceViewModel(importSources: [
            .chrome,
            .bitwarden,
            .csv,
            .bookmarksHTML,
            .onePassword8,
            .onePassword7,
            .lastPass,
        ], selectedSource: .bitwarden)

        XCTAssertEqual(model.importSources, [
            .chrome,
            .bitwarden,
            nil,
            .csv,
            .bookmarksHTML,
            nil,
            .onePassword8,
            .onePassword7,
            .lastPass,
        ])
    }

    func testWhenUnavailableSelectedSourcePassed_selectedSourceIndexIs0() {
        let model = DataImportSourceViewModel(importSources: [.csv], selectedSource: .bitwarden)
        XCTAssertEqual(model.selectedSourceIndex, 0)
    }

}
