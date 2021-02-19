//
//  UserDefaultsWrapper.swift
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

@propertyWrapper
struct UserDefaultsWrapper<T> {

    enum Key: String, CaseIterable {

        case fireproofDomains = "com.duckduckgo.fireproofing.allowedDomains"

    }

    private let key: Key
    private let defaultValue: T
    private let setIfEmpty: Bool

    init(key: Key, defaultValue: T, setIfEmpty: Bool = false) {
        self.key = key
        self.defaultValue = defaultValue
        self.setIfEmpty = setIfEmpty
    }

    var wrappedValue: T {
        get {
            if let storedValue = UserDefaults.standard.object(forKey: key.rawValue) as? T {
                return storedValue
            }

            if setIfEmpty {
                UserDefaults.standard.set(defaultValue, forKey: key.rawValue)
            }

            return defaultValue
        }
        set {
            UserDefaults.standard.set(newValue, forKey: key.rawValue)
        }
    }

    static func clearAll() {
        Key.allCases.forEach { key in
            UserDefaults.standard.removeObject(forKey: key.rawValue)
        }
    }
}
