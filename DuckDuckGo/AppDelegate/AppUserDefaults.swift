//
//  AppUserDefaults.swift
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

enum SessionRestorationMode: RawRepresentable {
    typealias RawValue = Bool?

    case systemDefined
    case always
    case never

    init(rawValue: Bool?) {
        switch rawValue {
        case .none:
            self = .systemDefined
        case .some(true):
            self = .always
        case .some(false):
            self = .never
        }
    }

    var rawValue: Bool? {
        switch self {
        case .systemDefined:
            return nil
        case .always:
            return true
        case .never:
            return false
        }
    }

}

protocol AppSettings: AnyObject {
    var restoreSessionAtLaunch: SessionRestorationMode { get set }
}

final class AppUserDefaults: AppSettings {
    static let shared = AppUserDefaults()

    private enum Keys {
        static let restoreSessionAtLaunchKey = "com.duckduckgo.app.restoreSessionAtLaunch"

    }

    private let suiteName: String?

    private var userDefaults: UserDefaults {
        suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }

    init(suiteName: String? = nil) {
        self.suiteName = suiteName
    }

    var restoreSessionAtLaunch: SessionRestorationMode {
        get {
            SessionRestorationMode(rawValue: userDefaults.object(forKey: Keys.restoreSessionAtLaunchKey) as? Bool)
        }
        set {
            if let boolValue = newValue.rawValue {
                userDefaults.setValue(boolValue, forKey: Keys.restoreSessionAtLaunchKey)
            } else {
                userDefaults.removeObject(forKey: Keys.restoreSessionAtLaunchKey)
            }
        }
    }
    
}
