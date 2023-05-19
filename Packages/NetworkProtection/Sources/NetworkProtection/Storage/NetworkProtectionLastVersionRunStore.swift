//
//  NetworkProtectionLastVersionRunStore.swift
//  DuckDuckGo
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

public final class NetworkProtectionLastVersionRunStore {
    private let userDefaults: UserDefaults

    static let lastVersionRunKey = "com.duckduckgo.network-protection.NetworkProtectionVersionStore.lastVersionRunKey"

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    public var lastVersionRun: String? {
        get {
            userDefaults.string(forKey: Self.lastVersionRunKey)
        }

        set {
            userDefaults.set(newValue, forKey: Self.lastVersionRunKey)
        }
    }
}
