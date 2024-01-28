//
//  TransparentProxySettings.swift
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

/// This right now only includes
///
public struct AppIdentifier: Codable {
    public let bundleID: String

    public init(bundleID: String) {
        self.bundleID = bundleID
    }
}

/// Just a convenient enum to make excluding features more semantically clear.
///
public enum FeatureExclusion: Codable {
    case dontExclude
    case exclude(_ appIdentifier: AppIdentifier)
}

public final class TransparentProxySettings {
    let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public var dryMode: Bool {
        get {
            defaults.vpnProxyDryMode
        }

        set {
            defaults.vpnProxyDryMode = newValue
        }
    }

    public var excludeDBP: FeatureExclusion {
        get {
            defaults.vpnProxyExcludeDBP
        }

        set {
            defaults.vpnProxyExcludeDBP = newValue
        }
    }

    public var excludedApps: [AppIdentifier] {
        get {
            defaults.vpnProxyExcludedApps
        }

        set {
            defaults.vpnProxyExcludedApps = newValue
        }
    }

    // MARK: - Snapshot support

    public func snapshot() -> TransparentProxySettingsSnapshot {
        .init(dryMode: dryMode, excludeDBP: excludeDBP, excludedApps: excludedApps)
    }

    public func apply(_ snapshot: TransparentProxySettingsSnapshot) {
        dryMode = snapshot.dryMode
        excludeDBP = snapshot.excludeDBP
        excludedApps = snapshot.excludedApps
    }
}

public struct TransparentProxySettingsSnapshot: Codable {
    public static let key = "com.duckduckgo.TransparentProxySettingsSnapshot"

    public let dryMode: Bool
    public let excludeDBP: FeatureExclusion
    public let excludedApps: [AppIdentifier]
}
