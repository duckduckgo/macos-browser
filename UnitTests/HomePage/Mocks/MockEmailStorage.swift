//
//  MockEmailStorage.swift
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
@testable import DuckDuckGo_Privacy_Browser
import BrowserServicesKit

class MockEmailStorage: EmailManagerStorage {
    var isEmailProtectionEnabled = false

    func getUsername() throws -> String? {
        if isEmailProtectionEnabled {
            return "Pizza is amazing"
        }
        return nil
    }

    func getToken() throws -> String? {
        if isEmailProtectionEnabled {
            return "It really is!"
        }
        return nil
    }

    func getAlias() throws -> String? {
        return nil
    }

    func getCohort() throws -> String? {
        return nil
    }

    func getLastUseDate() throws -> String? {
        return nil
    }

    func store(token: String, username: String, cohort: String?) throws {
    }

    func store(alias: String) throws {
    }

    func store(lastUseDate: String) throws {
    }

    func deleteAlias() throws {
    }

    func deleteAuthenticationState() throws {
    }

    func deleteWaitlistState() throws {
    }
}
