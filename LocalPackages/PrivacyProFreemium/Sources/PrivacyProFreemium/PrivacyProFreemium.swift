//
//  PrivacyProFreemium.swift
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

extension Bundle {

    static let subsAppGroupName = "SUBSCRIPTION_APP_GROUP"

    var appGroupName: String {
        guard let appGroup = object(forInfoDictionaryKey: Bundle.subsAppGroupName) as? String else {
            fatalError("Info.plist is missing \(Bundle.subsAppGroupName)")
        }
        return appGroup
    }
}

extension UserDefaults {
    static let subs = UserDefaults(suiteName: Bundle.main.subsAppGroup)!
}

extension Bundle {

    var subsAppGroup: String {
        guard let appGroup = object(forInfoDictionaryKey: Bundle.subsAppGroupName) as? String else {
            fatalError("Info.plist is missing \(appGroupName)")
        }
        return appGroup
    }
}

public protocol PrivacyProFreemium {
    static var isFreemium: Bool { get }
}

public struct DefaultPrivacyProFreemium: PrivacyProFreemium {
    private static let key = "macos.browser.privacy-pro.freemium"

    public static var isFreemium: Bool {
        get {
            UserDefaults.subs.bool(forKey: key)
        }
        set {
            UserDefaults.subs.setValue(newValue, forKey: key)
        }
    }
}
