//
//  MaliciousSiteProtectionRemoteSettings.swift
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
import PixelKit

protocol MaliciousSiteProtectionRemoteSettingsProvider {
    subscript<T: MaliciousSiteProtectionRemoteSettings.SettingsKey>(key: T) -> T.Value { get }
}

extension MaliciousSiteProtectionRemoteSettings.SettingsKey where Self == MaliciousSiteProtectionRemoteSettings.Key<TimeInterval> {
    static var hashPrefixUpdateFrequencyMinutes: Self { Self(key: "hashPrefixUpdateFrequency", defaultValue: 20) }
    static var filterSetUpdateFrequencyMinutes: Self { Self(key: "filterSetUpdateFrequency", defaultValue: 720) }
}
extension MaliciousSiteProtectionRemoteSettings.SettingsKey where Value == Bool {}

/// This struct serves as a wrapper for PrivacyConfigurationManaging, enabling the retrieval of data relevant to MaliciousSiteProtection.
struct MaliciousSiteProtectionRemoteSettings: MaliciousSiteProtectionRemoteSettingsProvider {

    public protocol SettingsKey {
        /// The associated type representing the type of the Settings key's value.
        associatedtype Value

        /// The Settings key.
        var rawValue: String { get }

        /// The default value for the Settings key.
        var defaultValue: Self.Value { get }
    }

    public struct Key<Value>: SettingsKey {
        public let rawValue: String
        public let defaultValue: Value

        public init(key: String, defaultValue: Value) {
            self.rawValue = key
            self.defaultValue = defaultValue
        }

        public init<Wrapped>(key: String) where Value == Wrapped? {
            self.rawValue = key
            self.defaultValue = nil
        }
    }

    private let privacyConfigurationManager: PrivacyConfigurationManaging
    private var settings: PrivacyConfigurationData.PrivacyFeature.FeatureSettings {
        privacyConfigurationManager.privacyConfig.settings(for: .maliciousSiteProtection)
    }

    init(privacyConfigurationManager: PrivacyConfigurationManaging = AppPrivacyFeatures.shared.contentBlocking.privacyConfigurationManager) {
        self.privacyConfigurationManager = privacyConfigurationManager
    }

    subscript<T: MaliciousSiteProtectionRemoteSettings.SettingsKey>(key: T) -> T.Value {
        guard let value = settings[key.rawValue] else {
            return key.defaultValue
        }

        // perform number conversion if needed
        guard let typedValue: T.Value = ((T.Value.self as? SettingValueConvertible.Type)?.init(anyValue: value) ?? value) as? T.Value else {
            assertionFailure("Unexpected type of value for \(key.rawValue): \(type(of: value)) (\(value))")
            return key.defaultValue
        }
        return typedValue
    }

}

private protocol SettingValueConvertible {
    init?(anyValue: Any)
}
extension Double: SettingValueConvertible {
    public init?(anyValue: Any) {
        switch anyValue {
        case let int as Int:
            self = Self(int)
        case let double as Double:
            self = double
        default:
            return nil
        }
    }
}
extension Int: SettingValueConvertible {
    public init?(anyValue: Any) {
        switch anyValue {
        case let int as Int:
            self = int
        case let double as Double:
            self = Int(double)
        default:
            return nil
        }
    }
}
extension Bool: SettingValueConvertible {
    public init?(anyValue: Any) {
        switch anyValue {
        case let int as Int:
            self = (int != 0)
        case let double as Double:
            self = (double != 0)
        default:
            return nil
        }
    }
}
