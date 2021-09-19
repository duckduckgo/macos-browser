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

    var oldSelection: SecureVaultModels.WebsiteAccount?
    var newSelection: SecureVaultModels.WebsiteAccount?

    func testWhenAccountIsSelctedThenModelReflectsThat() {
        let accounts = (0 ..< 10).map { makeAccount(id: $0, domain: "domain\($0)") }
        let model = PasswordManagementItemListModel(onItemSelected: onItemSelected)

        model.accounts = accounts
        model.selectAccount(accounts[0])
        XCTAssertNotNil(model.selected)

        model.selectItem(with : accounts[8].id!)
        XCTAssertEqual(model.selected?.id, 8)

        model.clearSelection()
        XCTAssertNil(model.selected)

        model.selectFirst()
        XCTAssertEqual(model.selected?.id, 0)
        
    }

    func testWhenFilterAppliedThenDisplayedAccountsOnlyContainFilteredMatches() {

        let accounts = (0 ..< 10).map { makeAccount(id: $0, domain: "domain\($0)") }
        let model = PasswordManagementItemListModel(onItemSelected: onItemSelected)

        model.accounts = accounts
        model.filter = "domain5"

        XCTAssertEqual(model.displayedAccounts.count, 1)
        XCTAssertEqual(model.displayedAccounts[0].domain, "domain5")

        model.filter = ""
        XCTAssertEqual(model.displayedAccounts.count, 10)
        XCTAssertEqual(model.displayedAccounts[0].domain, "domain0")
        XCTAssertEqual(model.displayedAccounts[9].domain, "domain9")
    }

    func testWhenAccountIsSelectedThenCallbackReceivesOldAndNewVersion() {
        let model = PasswordManagementItemListModel(onItemSelected: onItemSelected)
        let account = makeAccount(id: 1)
        model.selectAccount(account)

        XCTAssertNil(oldSelection)
        XCTAssertNotNil(newSelection)
    }

    func makeAccount(id: Int64, title: String? = nil, username: String = "username", domain: String = "domain") -> SecureVaultModels.WebsiteAccount {
        return SecureVaultModels.WebsiteAccount(id: id,
                                                title: title,
                                                username: username,
                                                domain: domain)
    }

    func onItemSelected(old: SecureVaultModels.WebsiteAccount?, new: SecureVaultModels.WebsiteAccount) {
        oldSelection = old
        newSelection = new
    }

}
