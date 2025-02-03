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
import Combine
import AppKitExtensions

public final class DataBrokerProtectionSettings {
    private let defaults: UserDefaults

    private enum Keys {
        static let runType = "dbp.environment.run-type"
    }

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

    // MARK: - Environment

    public var selectedEnvironment: SelectedEnvironment {
        get {
            defaults.dataBrokerProtectionSelectedEnvironment
        }

        set {
            defaults.dataBrokerProtectionSelectedEnvironment = newValue
        }
    }

    public func updateStoredRunType() {
        storedRunType = NSApplication.runType
    }

    public private(set) var storedRunType: NSApplication.RunType? {
        get {
            guard let runType = UserDefaults.dbp.string(forKey: Keys.runType) else {
                return nil
            }
            return NSApplication.RunType(rawValue: runType)
        }
        set(runType) {
            UserDefaults.dbp.set(runType?.rawValue, forKey: Keys.runType)
        }
    }

    // MARK: - Show in Menu Bar

    public var showInMenuBarPublisher: AnyPublisher<Bool, Never> {
        defaults.networkProtectionSettingShowInMenuBarPublisher
    }

    public var showInMenuBar: Bool {
        get {
            defaults.dataBrokerProtectionShowMenuBarIcon
        }

        set {
            defaults.dataBrokerProtectionShowMenuBarIcon = newValue
        }
    }
}

extension UserDefaults {
    private var selectedEnvironmentKey: String {
        "dataBrokerProtectionSelectedEnvironmentRawValue"
    }

    static let showMenuBarIconDefaultValue = false
    private var showMenuBarIconKey: String {
        "dataBrokerProtectionShowMenuBarIcon"
    }

    // MARK: - Environment

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

    // MARK: - Show in Menu Bar

    @objc
    dynamic var dataBrokerProtectionShowMenuBarIcon: Bool {
        get {
            value(forKey: showMenuBarIconKey) as? Bool ?? Self.showMenuBarIconDefaultValue
        }

        set {
            guard newValue != dataBrokerProtectionShowMenuBarIcon else {
                return
            }

            set(newValue, forKey: showMenuBarIconKey)
        }
    }

    var networkProtectionSettingShowInMenuBarPublisher: AnyPublisher<Bool, Never> {
        publisher(for: \.dataBrokerProtectionShowMenuBarIcon).eraseToAnyPublisher()
    }
}
