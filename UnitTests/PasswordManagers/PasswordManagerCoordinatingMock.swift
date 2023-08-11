//
//  PasswordManagerCoordinatingMock.swift
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
import BrowserServicesKit
@testable import DuckDuckGo_Privacy_Browser

final class PasswordManagerCoordinatingMock: PasswordManagerCoordinating {

    var isEnabled: Bool = false
    var isLocked: Bool = false

    var name: String = ""
    var displayName: String = ""

    func accountsFor(domain: String, completion: @escaping ([BrowserServicesKit.SecureVaultModels.WebsiteAccount], Error?) -> Void) {}

    func cachedAccountsFor(domain: String) -> [BrowserServicesKit.SecureVaultModels.WebsiteAccount] {
        return []
    }

    func cachedWebsiteCredentialsFor(domain: String, username: String) -> BrowserServicesKit.SecureVaultModels.WebsiteCredentials? {
        return nil
    }

    func websiteCredentialsFor(accountId: String, completion: @escaping (BrowserServicesKit.SecureVaultModels.WebsiteCredentials?, Error?) -> Void) {}

    func websiteCredentialsFor(domain: String, completion: @escaping ([BrowserServicesKit.SecureVaultModels.WebsiteCredentials], Error?) -> Void) {}

    func askToUnlock(completionHandler: @escaping () -> Void) {}

    func reportPasswordAutofill() {}

    func reportPasswordSave() {}

}
