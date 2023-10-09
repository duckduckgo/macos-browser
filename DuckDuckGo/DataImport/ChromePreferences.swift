//
//  ChromePreferences.swift
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

import AppKit

struct ChromePreferences: Decodable {

    struct AccountInfo: Decodable {
        let email: String?
        let fullName: String?
    }
    struct Profile: Decodable {
        let name: String
        let createdByVersion: String?
    }

    let accountInfo: [AccountInfo]?
    let profile: Profile

    init(from data: Data) throws {
        var decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        self = try decoder.decode(Self.self, from: data)
    }

    var profileName: String {
        for account in accountInfo ?? [] {
            switch (account.fullName, account.email) {
            case (.some(let fullName), .some(let email)):
                return "\(fullName) (\(email))"
            case (.some(let fullName), .none):
                return fullName
            case (.none, .some(let email)):
                return email
            case (.none, .none): continue
            }
        }
        return profile.name
    }

}
