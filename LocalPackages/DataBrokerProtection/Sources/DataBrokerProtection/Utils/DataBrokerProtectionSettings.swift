//
//  DataBrokerProtectionSettings.swift
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

public final class DataBrokerProtectionSettings {
    private let defaults: UserDefaults

    public enum SelectedEnvironment: String, Codable {
        case production
        case staging

        public static var `default`: SelectedEnvironment = .production

        public var endpointURL: URL {
            switch self {
            case .production:
                return URL(string: "https://dbp.duckduckgo.com")!
            case .staging:
                return URL(string: "https://dbp-staging.duckduckgo.com")!
            }
        }
    }

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public convenience init() {
        self.init(defaults: .dbp)
    }

    public var selectedEnvironment: SelectedEnvironment {
        get {
            defaults.dataBrokerProtectionSelectedEnvironment
        }

        set {
            defaults.dataBrokerProtectionSelectedEnvironment = newValue
        }
    }
}

extension UserDefaults {
    private var selectedEnvironmentKey: String {
        "dataBrokerProtectionSelectedEnvironmentRawValue"
    }

    @objc
    dynamic var dataBrokerProtectionSelectedEnvironmentRawValue: String {
        get {
            value(forKey: selectedEnvironmentKey) as? String ?? DataBrokerProtectionSettings.SelectedEnvironment.default.rawValue
        }

        set {
            set(newValue, forKey: selectedEnvironmentKey)
        }
    }

    var dataBrokerProtectionSelectedEnvironment: DataBrokerProtectionSettings.SelectedEnvironment {
        get {
            DataBrokerProtectionSettings.SelectedEnvironment(rawValue: dataBrokerProtectionSelectedEnvironmentRawValue) ?? .default
        }

        set {
            dataBrokerProtectionSelectedEnvironmentRawValue = newValue.rawValue
        }
    }
}
