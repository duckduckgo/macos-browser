//
//  CSVLoginExporterTests.swift
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
import BrowserServicesKit
@testable import DuckDuckGo_Privacy_Browser

class CSVLoginExporterTests: XCTestCase {

    func testWhenExportingLogins_ThenLoginsArePersistedToDisk() {
        let mockFileStore = FileStoreMock()
        let vault = MockSecureVault()

        let credentials = websiteCredentials(identifiers: [1])
        vault.storedAccounts = credentials.map(\.value.account)
        vault.storedCredentials = credentials

        let exporter = CSVLoginExporter(secureVault: vault, fileStore: mockFileStore)

        let mockURL = URL(fileURLWithPath: "mock-url")
        try? exporter.exportVaultLogins(to: mockURL)

        let data = mockFileStore.loadData(at: mockURL)
        XCTAssertNotNil(data)

        let expectedHeader = "\"title\",\"url\",\"username\",\"password\"\n"
        let expectedRow = "\"title-1\",\"domain-1\",\"user-1\",\"password\\\"containing\\\"quotes\""
        XCTAssertEqual(data, (expectedHeader + expectedRow).data(using: .utf8)!)
    }

    private func websiteCredentials(identifiers: [Int64]) -> [Int64: SecureVaultModels.WebsiteCredentials] {
        var credentials = [Int64: SecureVaultModels.WebsiteCredentials]()

        for identifier in identifiers {
            let account = SecureVaultModels.WebsiteAccount(id: String(identifier),
                                                           title: "title-\(identifier)",
                                                           username: "user-\(identifier)",
                                                           domain: "domain-\(identifier)")
            let credential = SecureVaultModels.WebsiteCredentials(account: account, password: "password\"containing\"quotes".data(using: .utf8)!)
            credentials[identifier] = credential
        }

        return credentials
    }

}
