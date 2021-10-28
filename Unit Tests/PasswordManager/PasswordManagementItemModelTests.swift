//
//  PasswordManagementItemModelTests.swift
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

final class PasswordManagementItemModelTests: XCTestCase {

    var isDirty = false
    var savedCredentials: SecureVaultModels.WebsiteCredentials?
    var deletedCredentials: SecureVaultModels.WebsiteCredentials?

    func testWhenCredentialsAreSavedThenSaveIsRequested() {
        let model = PasswordManagementLoginModel(onDirtyChanged: onDirtyChanged,
                                                onSaveRequested: onSaveRequested,
                                                onDeleteRequested: onDeleteRequested)

        model.credentials = makeCredentials(id: 1)
        model.save()
        XCTAssertEqual(savedCredentials?.account.id, 1)
        XCTAssertNil(deletedCredentials)

    }

    func testWhenCredentialsAreDeletedThenDeleteIsRequested() {
        let model = PasswordManagementLoginModel(onDirtyChanged: onDirtyChanged,
                                                onSaveRequested: onSaveRequested,
                                                onDeleteRequested: onDeleteRequested)

        model.credentials = makeCredentials(id: 1)
        model.requestDelete()
        XCTAssertEqual(deletedCredentials?.account.id, 1)
        XCTAssertNil(savedCredentials)

    }

    func testWhenCredentialsHasNoIdThenModelStateIsNew() {
        let model = PasswordManagementLoginModel(onDirtyChanged: onDirtyChanged,
                                                onSaveRequested: onSaveRequested,
                                                onDeleteRequested: onDeleteRequested)

        model.createNew()

        XCTAssertEqual(model.domain, "")
        XCTAssertEqual(model.username, "")
        XCTAssertTrue(model.isEditing)
        XCTAssertTrue(model.isNew)
        XCTAssertTrue(model.isDirty)
    }

    func testWhenModelIsEditedThenStateIsUpdated() {
        let model = PasswordManagementLoginModel(onDirtyChanged: onDirtyChanged,
                                                onSaveRequested: onSaveRequested,
                                                onDeleteRequested: onDeleteRequested)

        model.credentials = makeCredentials(id: 1)
        XCTAssertEqual(model.domain, "domain")
        XCTAssertEqual(model.username, "username")
        XCTAssertFalse(model.isEditing)
        XCTAssertFalse(model.isDirty)
        XCTAssertFalse(model.isNew)

        model.domain = "change"
        XCTAssertTrue(model.isDirty)
        XCTAssertTrue(isDirty)

        model.cancel()
        XCTAssertFalse(model.isDirty)
        XCTAssertFalse(isDirty)
        XCTAssertEqual(model.domain, "domain")

        model.title = "change"
        XCTAssertTrue(model.isDirty)
        XCTAssertTrue(isDirty)
        model.cancel()

        model.username = "change"
        XCTAssertTrue(model.isDirty)
        XCTAssertTrue(isDirty)
        model.cancel()

        model.password = "change"
        XCTAssertTrue(model.isDirty)
        XCTAssertTrue(isDirty)
        model.cancel()

    }

    func onDirtyChanged(isDirty: Bool) {
        self.isDirty = isDirty
    }

    func onSaveRequested(credentials: SecureVaultModels.WebsiteCredentials) {
        savedCredentials = credentials
    }

    func onDeleteRequested(credentials: SecureVaultModels.WebsiteCredentials) {
        deletedCredentials = credentials
    }

    func makeCredentials(id: Int64,
                         username: String = "username",
                         domain: String = "domain",
                         password: String = "password") -> SecureVaultModels.WebsiteCredentials {

        let account = SecureVaultModels.WebsiteAccount(id: id, username: username, domain: domain)
        return SecureVaultModels.WebsiteCredentials(account: account, password: password.data(using: .utf8)!)
    }

}

extension SecureVaultModels.WebsiteAccount {

    init(id: Int64, title: String? = nil, username: String = "username", domain: String = "domain") {
        self.init(title: title, username: username, domain: domain)
        self.id = id
    }

}
