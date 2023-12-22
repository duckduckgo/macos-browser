//
//  ChromiumPreferences.swift
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

struct ChromiumPreferences: Decodable {

    struct AccountInfo: Decodable {
        let email: String?
        let fullName: String?
    }
    struct Profile: Decodable {
        let name: String?
        let createdByVersion: String?
    }
    struct Extensions: Decodable {
        let lastChromeVersion: String?
        let lastOperaVersion: String?
    }

    enum Constants {
        static let chromiumPreferencesFileName = "Preferences"
    }

    let accountInfo: [AccountInfo]?
    let profile: Profile

    let extensions: Extensions?

    init(from data: Data) throws {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        self = try decoder.decode(Self.self, from: data)
    }

    init(profileURL: URL, fileStore: FileStore = FileManager.default) throws {
        guard let preferencesData = fileStore.loadData(at: profileURL.appendingPathComponent(Constants.chromiumPreferencesFileName)) else {
            throw CocoaError(.fileReadUnknown)
        }
        try self.init(from: preferencesData)
    }

    var profileName: String? {
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

    var appVersion: String? {
        // profile.createdByVersion updated on Chrome launch;
        // if it‘s missing - check extensions.last_chrome_version or last_opera_version - for Opera[GX]
        profile.createdByVersion ?? extensions?.lastChromeVersion ?? extensions?.lastOperaVersion
    }

}
