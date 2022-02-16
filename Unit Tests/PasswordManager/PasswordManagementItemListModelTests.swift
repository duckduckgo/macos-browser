//
//  PasswordManagementItemListModelTests.swift
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
import BrowserServicesKit
@testable import DuckDuckGo_Privacy_Browser

final class PasswordManagementItemListModelTests: XCTestCase {

    var oldSelection: SecureVaultItem?
    var newSelection: SecureVaultItem?

    func testWhenAccountIsSelectedThenModelReflectsThat() {
        let accounts = (0 ..< 10).map { makeAccount(id: $0, domain: "domain\($0)") }
        let model = PasswordManagementItemListModel(onItemSelected: onItemSelected)

        model.update(items: accounts)
        model.select(item: accounts[0])
        XCTAssertNotNil(model.selected)

        model.select(item: accounts[8])
        XCTAssertEqual(model.selected?.id, String(describing: accounts[8]))

        model.clearSelection()
        XCTAssertNil(model.selected)

        model.selectFirst()
        XCTAssertEqual(model.selected?.id, String(describing: accounts[0]))
        
    }

    func testWhenFilterAppliedThenDisplayedAccountsOnlyContainFilteredMatches() {

        let createdAccounts = (0 ..< 10).map { makeAccount(id: $0, domain: "domain\($0)") }
        let model = PasswordManagementItemListModel(onItemSelected: onItemSelected)

        model.update(items: createdAccounts)
        model.filter = "domain5"

        XCTAssertEqual(model.displayedItems.count, 1)

        let filteredAccounts = accounts(from: model.displayedItems)
        XCTAssertEqual(filteredAccounts[0].domain, "domain5")

        model.filter = ""

        let unfilteredAccounts = accounts(from: model.displayedItems)
        XCTAssertEqual(unfilteredAccounts.count, 10)
        XCTAssertEqual(unfilteredAccounts[0].domain, "domain0")
        XCTAssertEqual(unfilteredAccounts[9].domain, "domain9")
    }

    func testWhenAccountIsSelectedThenCallbackReceivesOldAndNewVersion() {
        let model = PasswordManagementItemListModel(onItemSelected: onItemSelected)
        let account = makeAccount(id: 1)

        model.update(items: [account])
        model.select(item: account)

        XCTAssertNil(oldSelection)
        XCTAssertNotNil(newSelection)
    }

    func makeAccount(id: Int64, title: String? = nil, username: String = "username", domain: String = "domain") -> SecureVaultItem {
        let account = SecureVaultModels.WebsiteAccount(id: id,
                                                title: title,
                                                username: username,
                                                domain: domain)
        return .account(account)
    }

    func onItemSelected(old: SecureVaultItem?, new: SecureVaultItem?) {
        oldSelection = old
        newSelection = new
    }

    private func accounts(from sections: [PasswordManagementListSection]) -> [SecureVaultModels.WebsiteAccount] {
        var accounts = [SecureVaultModels.WebsiteAccount]()

        for section in sections {
            let accountsFromItems: [SecureVaultModels.WebsiteAccount] = section.items.compactMap {
                switch $0 {
                case .account(let account): return account
                default: return nil
                }
            }

            accounts.append(contentsOf: accountsFromItems)
        }

        return accounts
    }

}
