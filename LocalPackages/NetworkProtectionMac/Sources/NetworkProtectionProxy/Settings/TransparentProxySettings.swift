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

public final class TransparentProxySettings {
    public enum Change: Codable {
        case appRoutingRules(_ routingRules: VPNAppRoutingRules)
        case dryMode(_ value: Bool)
        case excludedDomains(_ excludedDomains: [String])
    }

    let defaults: UserDefaults

    private(set) public lazy var changePublisher: AnyPublisher<Change, Never> = {
        Publishers.MergeMany(
            defaults.vpnProxyAppRoutingRulesPublisher
                .dropFirst()
                .removeDuplicates()
                .map { routingRules in
                    Change.appRoutingRules(routingRules)
                }.eraseToAnyPublisher(),
            defaults.vpnProxyDryModePublisher
                .dropFirst()
                .removeDuplicates()
                .map { value in
                    Change.dryMode(value)
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

    // MARK: - Settings

    public var appRoutingRules: VPNAppRoutingRules {
        get {
            defaults.vpnProxyAppRoutingRules
        }

        set {
            defaults.vpnProxyAppRoutingRules = newValue
        }
    }

    public var dryMode: Bool {
        get {
            defaults.vpnProxyDryMode
        }

        set {
            defaults.vpnProxyDryMode = newValue
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

    // MARK: - Reset to factory defaults

    public func resetAll() {
        defaults.resetVPNProxyAppRoutingRules()
        defaults.resetVPNProxyDryMode()
        defaults.resetVPNProxyExcludedDomains()
    }

    // MARK: - App routing rules logic

    public func isBlocking(_ appIdentifier: VPNRoutingAppIdentifier) -> Bool {
        appRoutingRules[appIdentifier] == .block
    }

    public func isExcluding(_ appIdentifier: VPNRoutingAppIdentifier) -> Bool {
        appRoutingRules[appIdentifier] == .exclude
    }

    public func toggleBlocking(for appIdentifier: VPNRoutingAppIdentifier) {
        if isBlocking(appIdentifier) {
            appRoutingRules.removeValue(forKey: appIdentifier)
        } else {
            appRoutingRules[appIdentifier] = .block
        }
    }

    public func toggleExclusion(for appIdentifier: VPNRoutingAppIdentifier) {
        if isExcluding(appIdentifier) {
            appRoutingRules.removeValue(forKey: appIdentifier)
        } else {
            appRoutingRules[appIdentifier] = .exclude
        }
    }

    // MARK: - Snapshot support

    public func snapshot() -> TransparentProxySettingsSnapshot {
        .init(appRoutingRules: appRoutingRules, dryMode: dryMode, excludedDomains: excludedDomains)
    }

    public func apply(_ snapshot: TransparentProxySettingsSnapshot) {
        appRoutingRules = snapshot.appRoutingRules
        dryMode = snapshot.dryMode
        excludedDomains = snapshot.excludedDomains
    }
}

public struct TransparentProxySettingsSnapshot: Codable {
    public static let key = "com.duckduckgo.TransparentProxySettingsSnapshot"

    public let appRoutingRules: VPNAppRoutingRules
    public let dryMode: Bool
    public let excludedDomains: [String]
}
