//
//  AppExclusionsManager.swift
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

import AppInfoRetriever
import Foundation
import Combine

/// Manages App routing rules.
///
/// This manager expands the routing rules stored in the Proxy settings to include the bundleIDs
/// of all embedded binaries.  This is useful because when blocking or excluding an app the user
/// likely expects the rule to extend to all child processes.
///
final class AppExclusionsManager {

    private(set) var appRoutingRules: VPNAppRoutingRules
    private var cancellables = Set<AnyCancellable>()

    init(settings: TransparentProxySettings) {
        self.appRoutingRules = Self.expandAppRoutingRules(settings.appRoutingRules)

        subscribeToAppRoutingRulesChanges(settings)
    }

    static func expandAppRoutingRules(_ rules: VPNAppRoutingRules) -> VPNAppRoutingRules {

        let appInfoRetriever = AppInfoRetriever()
        var expandedRules = rules

        for (bundleID, rule) in rules {
            guard let bundleURL = appInfoRetriever.getAppURL(bundleID: bundleID) else {
                continue
            }

            let embeddedAppBundleIDs = appInfoRetriever.findEmbeddedBundleIDs(in: bundleURL)

            for childBundleID in embeddedAppBundleIDs {
                expandedRules[childBundleID] = rule
            }
        }

        return expandedRules
    }

    private func subscribeToAppRoutingRulesChanges(_ settings: TransparentProxySettings) {
        settings.appRoutingRulesPublisher
            .receive(on: DispatchQueue.main)
            .map { rules in
                return Self.expandAppRoutingRules(rules)
            }
            .assign(to: \.appRoutingRules, onWeaklyHeld: self)
            .store(in: &cancellables)
    }
}
