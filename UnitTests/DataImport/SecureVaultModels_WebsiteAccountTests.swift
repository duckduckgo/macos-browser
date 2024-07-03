//
//  SecureVaultLoginImporterTests.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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
import GRDB
import BrowserServicesKit

final class SecureVaultModels_WebsiteAccountTests: XCTestCase {

    func test_strictDuplicate() {
        let original = SecureVaultModels.WebsiteAccount(title: "Blah", username: "blah123", domain: "blah.com", signature: "blah1blah2blah3", notes: "blah blah")
        let new = SecureVaultModels.WebsiteAccount(title: "Blah", username: "blah123", domain: "blah.com", notes: "blah blah")
        let isDuplicate = original.isDuplicateOf(accountToBeImported: new, signatureOfAccountToBeImported: "blah1blah2blah3")
        XCTAssertTrue(isDuplicate)
    }

    func test_strictAntithesis() {
        let original = SecureVaultModels.WebsiteAccount(title: "Blah", username: "blah123", domain: "blah.com", signature: "blah1blah2blah3", notes: "blah blah")
        let new = SecureVaultModels.WebsiteAccount(title: "Blerg", username: "blerg789", domain: "blerg.com", notes: "blehp di blerg blah")
        let isDuplicate = original.isDuplicateOf(accountToBeImported: new, signatureOfAccountToBeImported: "blerg0blerg4blerg2")
        XCTAssertFalse(isDuplicate)
    }

    // TODO: Add more cases
}
