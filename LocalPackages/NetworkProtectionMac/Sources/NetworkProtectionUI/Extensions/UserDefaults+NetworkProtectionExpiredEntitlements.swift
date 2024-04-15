//
//  UserDefaults+NetworkProtectionExpiredEntitlements.swift
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

import Foundation

public extension UserDefaults {
    private enum Key {
        static var networkProtectionEntitlementsExpired = "networkProtectionEntitlementsExpired"
    }

    // Convenience declaration
    private var networkProtectionEntitlementsExpiredRawValueKey: String {
        Key.networkProtectionEntitlementsExpired
    }

    /// For KVO to work across processes (Menu App + Main App) we need to declare this dynamic var in a `UserDefaults`
    /// extension, and the key for this property must match its name exactly.
    ///
    @objc
    dynamic var networkProtectionEntitlementsExpired: Bool {
        get {
            value(forKey: networkProtectionEntitlementsExpiredRawValueKey) as? Bool ?? false
        }

        set {
            set(newValue, forKey: networkProtectionEntitlementsExpiredRawValueKey)
        }
    }
}
