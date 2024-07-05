//
//  WebsiteAccount_isDuplicateTests.swift
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
import GRDB
import BrowserServicesKit

final class WebsiteAccount_isDuplicateTests: XCTestCase {

    func test_strictDuplicate_duplicate() {
        let original = SecureVaultModels.WebsiteAccount(title: "Blah", username: "blah123", domain: "blah.com", signature: "blah1blah2blah3", notes: "blah blah")
        let new = SecureVaultModels.WebsiteAccount(title: "Blah", username: "blah123", domain: "blah.com", notes: "blah blah")
        let isDuplicate = original.isDuplicateOf(accountToBeImported: new, signatureOfAccountToBeImported: "blah1blah2blah3", passwordToBeImported: "password123")
        XCTAssertTrue(isDuplicate)
    }

    func test_strictAntithesis_notDuplicate() {
        let original = SecureVaultModels.WebsiteAccount(title: "Blah", username: "blah123", domain: "blah.com", signature: "blah1blah2blah3", notes: "blah blah")
        let new = SecureVaultModels.WebsiteAccount(title: "Blerg", username: "blerg789", domain: "blerg.com", notes: "blehp di blerg blah")
        let isDuplicate = original.isDuplicateOf(accountToBeImported: new, signatureOfAccountToBeImported: "blerg0blerg4blerg2", passwordToBeImported: "password123")
        XCTAssertFalse(isDuplicate)
    }

    func test_differingUsernamesOnly_notDuplicate() {
        let original = SecureVaultModels.WebsiteAccount(title: "Blah", username: "blah123", domain: "blah.com", signature: "blah1blah2blah3", notes: "blah blah")
        let new = SecureVaultModels.WebsiteAccount(title: "Blah", username: "different123", domain: "blah.com", notes: "blah blah")
        let isDuplicate = original.isDuplicateOf(accountToBeImported: new, signatureOfAccountToBeImported: "blerg0blerg4blerg2", passwordToBeImported: "password123")
        XCTAssertFalse(isDuplicate)
    }

    func test_nil_usernameInStored_notDuplicate() {
        let original = SecureVaultModels.WebsiteAccount(title: "Blah", username: nil, domain: "blah.com", signature: "blah1blah2blah3", notes: "blah blah")
        let new = SecureVaultModels.WebsiteAccount(title: "Blah", username: "blah123", domain: "blah.com", notes: "blah blah")
        let isDuplicate = original.isDuplicateOf(accountToBeImported: new, signatureOfAccountToBeImported: "blah1blah2blah3", passwordToBeImported: "password123")
        XCTAssertFalse(isDuplicate)
    }

    func test_nil_usernameInImport_duplicate() {
        let original = SecureVaultModels.WebsiteAccount(title: "Blah", username: "blah123", domain: "blah.com", signature: "blah1blah2blah3", notes: "blah blah")
        let new = SecureVaultModels.WebsiteAccount(title: "Blah", username: nil, domain: "blah.com", notes: "blah blah")
        let isDuplicate = original.isDuplicateOf(accountToBeImported: new, signatureOfAccountToBeImported: "blah1blah2blah3", passwordToBeImported: "password123")
        // The end-to-end behaviour will actually be false due to the URL being used to create the signature
        // https://app.asana.com/0/0/1207598052765977/1207736565669077/f
        XCTAssertTrue(isDuplicate)
    }

    func test_differing_passwordsOnly_notDuplicate() {
        let original = SecureVaultModels.WebsiteAccount(title: "Blah", username: "blah123", domain: "blah.com", signature: "blah1blah2blah3", notes: "blah blah")
        let new = SecureVaultModels.WebsiteAccount(title: "Blah", username: "blah123", domain: "blah.com", notes: "blah blah")
        let isDuplicate = original.isDuplicateOf(accountToBeImported: new, signatureOfAccountToBeImported: "differentSignature123", passwordToBeImported: "password123")
        XCTAssertFalse(isDuplicate)
    }

    func test_nil_passwordInStored_duplicate() {
        let original = SecureVaultModels.WebsiteAccount(title: "Blah", username: "blah123", domain: "blah.com", signature: "nilPasswordStillHasSignature", notes: "blah blah")
        let new = SecureVaultModels.WebsiteAccount(title: "Blah", username: "blah123", domain: "blah.com", notes: "blah blah")
        let isDuplicate = original.isDuplicateOf(accountToBeImported: new, signatureOfAccountToBeImported: "nilPasswordStillHasSignature", passwordToBeImported: "password123")
        // The end-to-end behaviour will actually be false due to the URL being used to create the signature
        // https://app.asana.com/0/0/1207598052765977/1207736565669077/f
        XCTAssertTrue(isDuplicate)
    }

    func test_nil_passwordInImport_duplicate() {
        let original = SecureVaultModels.WebsiteAccount(title: "Blah", username: "blah123", domain: "blah.com", signature: "blah1blah2blah3", notes: "blah blah")
        let new = SecureVaultModels.WebsiteAccount(title: "Blah", username: "blah123", domain: "blah.com", notes: "blah blah")
        let isDuplicate = original.isDuplicateOf(accountToBeImported: new, signatureOfAccountToBeImported: "nilPasswordStillHasSignature", passwordToBeImported: nil)
        XCTAssertTrue(isDuplicate)
    }

    func test_differing_URLOnly_notDuplicate() {
        let original = SecureVaultModels.WebsiteAccount(title: "Blah", username: "blah123", domain: "blah.com", signature: "blah1blah2blah3", notes: "blah blah")
        let new = SecureVaultModels.WebsiteAccount(title: "Blah", username: "blah123", domain: "differing.com", notes: "blah blah")
        let isDuplicate = original.isDuplicateOf(accountToBeImported: new, signatureOfAccountToBeImported: "blah1blah2blah3", passwordToBeImported: "password123")
        XCTAssertFalse(isDuplicate)
    }

    func test_nil_URLInStored_notDuplicate() {
        let original = SecureVaultModels.WebsiteAccount(title: "Blah", username: "blah123", domain: nil, signature: "blah1blah2blah3", notes: "blah blah")
        let new = SecureVaultModels.WebsiteAccount(title: "Blah", username: "blah123", domain: "blah.com", notes: "blah blah")
        let isDuplicate = original.isDuplicateOf(accountToBeImported: new, signatureOfAccountToBeImported: "blah1blah2blah3", passwordToBeImported: "password123")
        XCTAssertFalse(isDuplicate)
    }

    func test_nil_URLInImport_duplicate() {
        let original = SecureVaultModels.WebsiteAccount(title: "Blah", username: "blah123", domain: "blah.com", signature: "blah1blah2blah3", notes: "blah blah")
        let new = SecureVaultModels.WebsiteAccount(title: "Blah", username: "blah123", domain: nil, notes: "blah blah")
        let isDuplicate = original.isDuplicateOf(accountToBeImported: new, signatureOfAccountToBeImported: "blah1blah2blah3", passwordToBeImported: "password123")
        // The end-to-end behaviour will actually be false due to the URL being used to create the signature
        // https://app.asana.com/0/0/1207598052765977/1207736565669077/f
        XCTAssertTrue(isDuplicate)
    }

    func test_differing_notesOnly_notDuplicate() {
        let original = SecureVaultModels.WebsiteAccount(title: "Blah", username: "blah123", domain: "blah.com", signature: "blah1blah2blah3", notes: "blah blah")
        let new = SecureVaultModels.WebsiteAccount(title: "Blah", username: "blah123", domain: "blah.com", notes: "differing notes")
        let isDuplicate = original.isDuplicateOf(accountToBeImported: new, signatureOfAccountToBeImported: "blah1blah2blah3", passwordToBeImported: "password123")
        XCTAssertFalse(isDuplicate)
    }

    func test_nil_notesInStored_notDuplicate() {
        let original = SecureVaultModels.WebsiteAccount(title: "Blah", username: "blah123", domain: "blah.com", signature: "blah1blah2blah3", notes: nil)
        let new = SecureVaultModels.WebsiteAccount(title: "Blah", username: "blah123", domain: "blah.com", notes: "blah blah")
        let isDuplicate = original.isDuplicateOf(accountToBeImported: new, signatureOfAccountToBeImported: "blah1blah2blah3", passwordToBeImported: "password123")
        XCTAssertFalse(isDuplicate)
    }

    func test_nil_notesInImport_duplicate() {
        let original = SecureVaultModels.WebsiteAccount(title: "Blah", username: "blah123", domain: "blah.com", signature: "blah1blah2blah3", notes: "blah blah")
        let new = SecureVaultModels.WebsiteAccount(title: "Blah", username: "blah123", domain: "blah.com", notes: nil)
        let isDuplicate = original.isDuplicateOf(accountToBeImported: new, signatureOfAccountToBeImported: "blah1blah2blah3", passwordToBeImported: "password123")
        XCTAssertTrue(isDuplicate)
    }

    func test_differing_titleOnly_notDuplicate() {
        let original = SecureVaultModels.WebsiteAccount(title: "Blah", username: "blah123", domain: "blah.com", signature: "blah1blah2blah3", notes: "blah blah")
        let new = SecureVaultModels.WebsiteAccount(title: "Different", username: "blah123", domain: "blah.com", notes: "blah blah")
        let isDuplicate = original.isDuplicateOf(accountToBeImported: new, signatureOfAccountToBeImported: "blah1blah2blah3", passwordToBeImported: "password123")
        XCTAssertFalse(isDuplicate)
    }

    func test_nil_titleInStored_notDuplicate() {
        let original = SecureVaultModels.WebsiteAccount(title: nil, username: "blah123", domain: "blah.com", signature: "blah1blah2blah3", notes: "blah blah")
        let new = SecureVaultModels.WebsiteAccount(title: "Blah", username: "blah123", domain: "blah.com", notes: "blah blah")
        let isDuplicate = original.isDuplicateOf(accountToBeImported: new, signatureOfAccountToBeImported: "blah1blah2blah3", passwordToBeImported: "password123")
        XCTAssertFalse(isDuplicate)
    }

    func test_nil_titleInImport_duplicate() {
        let original = SecureVaultModels.WebsiteAccount(title: "Blah", username: "blah123", domain: "blah.com", signature: "blah1blah2blah3", notes: "blah blah")
        let new = SecureVaultModels.WebsiteAccount(title: nil, username: "blah123", domain: "blah.com", notes: "blah blah")
        let isDuplicate = original.isDuplicateOf(accountToBeImported: new, signatureOfAccountToBeImported: "blah1blah2blah3", passwordToBeImported: "password123")
        XCTAssertTrue(isDuplicate)
    }
}
