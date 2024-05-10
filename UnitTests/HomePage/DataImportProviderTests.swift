//
//  DataImportProviderTests.swift
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

import XCTest
@testable import DuckDuckGo_Privacy_Browser
import BrowserServicesKit

final class DataImportProviderTests: XCTestCase {

    var provider: DataImportStatusProviding!
    var vault: MockSecureVault<MockDatabaseProvider>!
    var bookmarkManager: MockBookmarkManager!

    let key = "home.page.continue.set.up.import"
    let importedAccounts = [
        SecureVaultModels.WebsiteAccount(id: "1", username: "", domain: "", created: Date(), lastUpdated: Date()),
        SecureVaultModels.WebsiteAccount(id: "2", username: "", domain: "", created: Date().startOfDay, lastUpdated: Date()),
        SecureVaultModels.WebsiteAccount(id: "3", username: "", domain: "", created: Date(), lastUpdated: Date())]
    let notImportedAccounts = [
        SecureVaultModels.WebsiteAccount(id: "1", username: "", domain: "", created: Date().addingTimeInterval(-10), lastUpdated: Date()),
        SecureVaultModels.WebsiteAccount(id: "2", username: "", domain: "", created: Date().startOfDay, lastUpdated: Date()),
        SecureVaultModels.WebsiteAccount(id: "3", username: "", domain: "", created: Date(), lastUpdated: Date())]
    let importedNotes = [
        SecureVaultModels.Note(text: "1"),
        SecureVaultModels.Note(text: "2"),
        SecureVaultModels.Note(text: "3")]
    let importedIdentities = [
        SecureVaultModels.Identity(id: 1, created: Date(), lastUpdated: Date()),
        SecureVaultModels.Identity(id: 2, created: Date().startOfDay, lastUpdated: Date()),
        SecureVaultModels.Identity(id: 3, created: Date(), lastUpdated: Date())]
    let notImportedIdentities = [
        SecureVaultModels.Identity(id: 1, created: Date(), lastUpdated: Date()),
        SecureVaultModels.Identity(id: 2, created: Date().startOfDay, lastUpdated: Date())]
    let importedCards = [
        SecureVaultModels.CreditCard(cardNumber: "4345", cardholderName: "", cardSecurityCode: "", expirationMonth: nil, expirationYear: nil),
        SecureVaultModels.CreditCard(cardNumber: "5243", cardholderName: "", cardSecurityCode: "", expirationMonth: nil, expirationYear: nil)]
    let importedBookmarkList = BookmarkList(topLevelEntities: [Bookmark(id: "test", url: "", title: "Something", isFavorite: false), Bookmark(id: "test", url: "", title: "\(UserText.bookmarkImportedFromFolder) Safari", isFavorite: false)])
    let notImportedBookmarkList = BookmarkList(topLevelEntities: [Bookmark(id: "test", url: "", title: "Something", isFavorite: false), Bookmark(id: "test", url: "", title: "Impori", isFavorite: false)])

    override func setUp() {
        UserDefaultsWrapper<Any>.clearAll()

        vault = try! MockSecureVaultFactory.makeVault(reporter: nil)
        vault.storedAccounts = notImportedAccounts
        vault.storedIdentities = []
        vault.storedCards = []
        vault.storedNotes = []

        bookmarkManager = MockBookmarkManager()
        bookmarkManager.list = notImportedBookmarkList

        provider = BookmarksAndPasswordsImportStatusProvider(secureVault: vault, bookmarkManager: bookmarkManager)
    }

    override func tearDown() {
        vault = nil
        bookmarkManager = nil
        provider = nil
    }

    func testWhenNoImportedPasswordsAndNoBookmarksDetectableAndNoSuccessImportThenDidImportIsFalse() {
        XCTAssertFalse(provider.didImport)
    }

    func testWhenImportedAccountsDetectedAndNoImportedBookmarksDetectableAndNoSuccessImportDidImportIsTrue() {
        vault.storedAccounts = importedAccounts

        XCTAssertTrue(provider.didImport)
    }

    func testWhenImportedNotesetectedAndNoImportedBookmarksDetectableAndNoSuccessImportThenDidImportIsTrue() {
        vault.storedNotes = importedNotes

        XCTAssertTrue(provider.didImport)
    }

    func testWhenImportedIdentitiesDetectedAndNoImportedBookmarksDetectableAndNoSuccessImportThenDidImportIsTrue() {
        vault.storedIdentities = importedIdentities

        XCTAssertTrue(provider.didImport)
    }

    func testWhenImportedCardsPasswordsDetectedAndNoImportedBookmarksDetectableAndNoSuccessImportThenDidImportIsTrue() {
        vault.storedCards = importedCards

        XCTAssertTrue(provider.didImport)
    }

    func testWhenNoImportedPasswordsDetectedAndImprotedBookmarksDetectedAndNoSuccessImportThenDidImportIsTrue() {
        bookmarkManager.list = importedBookmarkList

        XCTAssertTrue(provider.didImport)
    }

    func testWhenNoPasswordsAndNoBookmarksDetectableAndSuccessImportThenDidImportIsTrue() {
        let model = DataImportViewModel()
        model.successfulImportHappened = true

        XCTAssertTrue(provider.didImport)
    }

}
