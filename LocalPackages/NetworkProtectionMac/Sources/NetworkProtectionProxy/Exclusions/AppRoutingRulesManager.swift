//
//  ExclusionsManager.swift
//  NetworkProtectionMac
//
//  Created by ddg on 2/4/25.
//

import AppInfoRetriever

/// Manages App routing rules.
///
/// This manager expands the routing rules stored in the Proxy settings to include the bundleIDs
/// of all embedded binaries.  This is useful because when blocking or excluding an app the user
/// likely expects the rule to extend to all child processes.
///
final class AppExclusionsManager {

    let appRoutingRules: VPNAppRoutingRules
    private let settings: TransparentProxySettings

    init(settings: TransparentProxySettings) {
        self.settings = settings

        let appInfoRetriever = AppInfoRetriever()
        var expandedRules = settings.appRoutingRules

        for (bundleID, rule) in settings.appRoutingRules {
            guard let bundleURL = appInfoRetriever.getAppURL(bundleID: bundleID) else {
                continue
            }

            let embeddedAppBundleIDs = appInfoRetriever.findEmbeddedBundleIDs(in: bundleURL)

            for childBundleID in embeddedAppBundleIDs {
                expandedRules[childBundleID] = rule
            }
        }

        self.appRoutingRules = expandedRules
    }
}
