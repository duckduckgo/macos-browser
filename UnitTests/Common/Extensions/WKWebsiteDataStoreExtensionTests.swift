//
//  WKWebsiteDataStoreExtensionTests.swift
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

final class WKWebsiteDataStoreExtensionTests: XCTestCase {

    func testWhenGettingRemovableDataTypes_ThenLocalStorageAndIndexedDBAreNotIncluded() {
        let removableTypes = WKWebsiteDataStore.safelyRemovableWebsiteDataTypes

        XCTAssertFalse(removableTypes.contains(WKWebsiteDataTypeLocalStorage))

        if #available(macOS 12.2, *) {
            XCTAssertFalse(removableTypes.contains(WKWebsiteDataTypeIndexedDBDatabases))
        } else {
            XCTAssertTrue(removableTypes.contains(WKWebsiteDataTypeIndexedDBDatabases))
        }
    }

    func testWhenGettingAllWebsiteDataTypesExceptCookies_ThenLocalStorageAndIndexedDBAreIncluded() {
        let removableTypes = WKWebsiteDataStore.allWebsiteDataTypesExceptCookies

        XCTAssertFalse(removableTypes.contains(WKWebsiteDataTypeCookies))

        XCTAssertTrue(removableTypes.contains(WKWebsiteDataTypeLocalStorage))
        XCTAssertTrue(removableTypes.contains(WKWebsiteDataTypeIndexedDBDatabases))
    }

}
