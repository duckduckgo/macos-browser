//
//  UserDefaults+AutofillLoginImportUserScriptDelegate.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

import BrowserServicesKit

extension UserDefaults: AutofillLoginImportStateProvider {
    private enum Key {
        static let hasImportedLogins: String = "com.duckduckgo.logins.hasImportedLogins"
    }

    public var isNewDDGUser: Bool {
        guard let date = object(forKey: UserDefaultsWrapper<Date>.Key.firstLaunchDate.rawValue) as? Date else {
            return true
        }
        return date >= Date.weekAgo
    }

    public var hasImportedLogins: Bool {
        get {
            bool(forKey: Key.hasImportedLogins)
        }

        set {
            set(newValue, forKey: Key.hasImportedLogins)
        }
    }
}
