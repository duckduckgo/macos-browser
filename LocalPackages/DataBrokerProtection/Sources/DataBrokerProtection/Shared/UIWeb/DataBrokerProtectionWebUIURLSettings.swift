//
//  DataBrokerProtectionWebUIURLSettings.swift
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

public enum DataBrokerProtectionWebUIURLType: String, Codable {
    case production
    case custom
}

public protocol DataBrokerProtectionWebUIURLSettingsRepresentable {
    var customURL: String? { get }
    var productionURL: String { get }
    var selectedURL: String { get }

    var selectedURLType: DataBrokerProtectionWebUIURLType { get }
    var selectedURLHostname: String { get }

    func setCustomURL(_ url: String)
    func setURLType(_ type: DataBrokerProtectionWebUIURLType)
}

public final class DataBrokerProtectionWebUIURLSettings: DataBrokerProtectionWebUIURLSettingsRepresentable {

    public let productionURL = "https://duckduckgo.com/dbp"
    private let userDefault: UserDefaults

    public var selectedURLType: DataBrokerProtectionWebUIURLType {
        if let typeRawValue = userDefault.string(forKey: UserDefaults.Key.urlType.rawValue),
           let type = DataBrokerProtectionWebUIURLType(rawValue: typeRawValue) {
            return type
        } else {
            return .production
        }
    }

    public var customURL: String? {
        userDefault[.customURLValue]
    }

    public var selectedURLHostname: String {
        selectedURL.hostname ?? ""
    }

    public init(_ userDefault: UserDefaults) {
        self.userDefault = userDefault
    }

    public var selectedURL: String {
        switch selectedURLType {
        case .production:
            return productionURL
        case .custom:
            return customURL ?? ""
        }
    }

    public func setCustomURL(_ url: String) {
        userDefault[.customURLValue] = url
    }

    public func setURLType(_ type: DataBrokerProtectionWebUIURLType) {
        userDefault[.urlType] = type.rawValue
    }
}

private extension String {
    var hostname: String? {
        if let url = URL(string: self) {
            if let host = url.host, let port = url.port {
                return "\(host):\(port)"
            }
            return url.host
        }
        return nil
    }
}

private extension UserDefaults {
    enum Key: String {
        case customURLValue
        case urlType
    }

    subscript<T>(key: Key) -> T? where T: Any {
        get {
            return value(forKey: key.rawValue) as? T
        }
        set {
            set(newValue, forKey: key.rawValue)
        }
    }

}
