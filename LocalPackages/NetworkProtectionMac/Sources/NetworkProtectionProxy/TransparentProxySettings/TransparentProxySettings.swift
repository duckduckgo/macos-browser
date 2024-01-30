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

import Combine
import Foundation

/// This right now only includes
///
public struct AppIdentifier: Codable, Equatable {
    public let bundleID: String

    public init(bundleID: String) {
        self.bundleID = bundleID
    }
}

public final class TransparentProxySettings {
    public enum Change: Codable {
        case dryMode(_ value: Bool)
        case excludeDBP(_ value: Bool)
        case excludedApps(_ excludedApps: [AppIdentifier])
        case excludedDomains(_ excludedDomains: [String])
    }

    let defaults: UserDefaults

    private(set) public lazy var changePublisher: AnyPublisher<Change, Never> = {
        Publishers.MergeMany(
            defaults.vpnProxyDryModePublisher
                .dropFirst()
                .removeDuplicates()
                .map { value in
                    Change.dryMode(value)
                }.eraseToAnyPublisher(),
            defaults.vpnProxyExcludeDBPPublisher
                .dropFirst()
                .removeDuplicates()
                .map { value in
                    Change.excludeDBP(value)
                }.eraseToAnyPublisher(),
            defaults.vpnProxyExcludedAppsPublisher
                .dropFirst()
                .removeDuplicates()
                .map { excludedApps in
                    Change.excludedApps(excludedApps)
                }.eraseToAnyPublisher(),
            defaults.vpnProxyExcludedDomainsPublisher
                .dropFirst()
                .removeDuplicates()
                .map { excludedDomains in
                    Change.excludedDomains(excludedDomains)
                }.eraseToAnyPublisher()
        ).eraseToAnyPublisher()
    }()

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

    public var excludeDBP: Bool {
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

    public var excludedDomains: [String] {
        get {
            defaults.vpnProxyExcludedDomains
        }

        set {
            defaults.vpnProxyExcludedDomains = newValue
        }
    }

    // MARK: - App Exclusions Support

    public func isExcluding(_ appIdentifier: AppIdentifier) -> Bool {
        excludedApps.contains(appIdentifier)
    }

    public func toggleExclusion(for appIdentifier: AppIdentifier) {
        if isExcluding(appIdentifier) {
            excludedApps.removeAll { $0 == appIdentifier }
        } else {
            excludedApps.append(appIdentifier)
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
    public let excludeDBP: Bool
    public let excludedApps: [AppIdentifier]
}
