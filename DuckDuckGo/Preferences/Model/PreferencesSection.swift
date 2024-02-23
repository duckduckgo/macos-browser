//
//  PreferencesSection.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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
import SwiftUI

#if SUBSCRIPTION
import Subscription
#endif

struct PreferencesSection: Hashable, Identifiable {
    let id: PreferencesSectionIdentifier
    let panes: [PreferencePaneIdentifier]

    @MainActor
    static func defaultSections(includingDuckPlayer: Bool, includingSync: Bool, includingVPN: Bool) -> [PreferencesSection] {
        var privacyPanes: [PreferencePaneIdentifier] = [.defaultBrowser, .privateSearch, .webTrackingProtection, .cookiePopupProtection, .emailProtection]

#if NETWORK_PROTECTION
        if includingVPN {
            privacyPanes.append(.vpn)
        }
#endif

        let regularPanes: [PreferencePaneIdentifier] = {
            var panes: [PreferencePaneIdentifier] = [.general, .appearance, .autofill, .downloads, .fireButton]

#if SUBSCRIPTION

            if NSApp.delegateTyped.internalUserDecider.isInternalUser {
                if let generalIndex = panes.firstIndex(of: .general) {
                    panes.insert(.sync, at: generalIndex + 1)
                }
            }

#else

            if includingSync {
                panes.insert(.sync, at: 1)
            }
#endif
            if includingDuckPlayer {
                panes.append(.duckPlayer)
            }

            return panes
        }()

#if SUBSCRIPTION
        var shouldIncludeSubscriptionPane = false
        if AccountManager().isUserAuthenticated || SubscriptionPurchaseEnvironment.canPurchase {
            shouldIncludeSubscriptionPane = true
        }

        return [
            .init(id: .privacyProtections, panes: privacyPanes),
            (shouldIncludeSubscriptionPane ? .init(id: .privacyPro, panes: [.subscription]) : nil),
            .init(id: .regularPreferencePanes, panes: regularPanes),
            .init(id: .about, panes: [.about])
        ].compactMap { $0 }
#else
        return [
            .init(id: .privacyProtections, panes: privacyPanes),
            .init(id: .regularPreferencePanes, panes: regularPanes),
            .init(id: .about, panes: [.about])
        ].compactMap { $0 }
#endif
    }
}

enum PreferencesSectionIdentifier: Hashable, CaseIterable {
    case privacyProtections
    case privacyPro
    case regularPreferencePanes
    case about

    var displayName: String? {
        switch self {
        case .privacyProtections:
            return "Privacy Protections"
        case .privacyPro:
            return nil
        case .regularPreferencePanes:
            return "Main Settings"
        case .about:
            return nil
        }
    }

}

enum PreferencePaneIdentifier: String, Equatable, Hashable, Identifiable {
    case defaultBrowser
    case privateSearch
    case webTrackingProtection
    case cookiePopupProtection
    case emailProtection

    case general
    case sync
    case appearance
    case fireButton
#if NETWORK_PROTECTION
    case vpn
#endif
#if SUBSCRIPTION
    case subscription
#endif
    case autofill
    case downloads
    case duckPlayer = "duckplayer"
    case about

    var id: Self {
        self
    }

    init?(url: URL) {
        // manually extract path because URLs such as "about:settings" can't figure out their host or path
        for urlPrefix in [URL.settings, URL.Invalid.aboutPreferences, URL.Invalid.aboutConfig, URL.Invalid.aboutSettings, URL.Invalid.duckConfig, URL.Invalid.duckPreferences] {
            let prefix = urlPrefix.absoluteString + "/"
            guard url.absoluteString.hasPrefix(prefix) else { continue }

            let path = url.absoluteString.dropping(prefix: prefix)
            self.init(rawValue: path)
            return
        }
        return nil
    }

    @MainActor
    var displayName: String {
        switch self {
        case .defaultBrowser:
            return "Default Browser App"
        case .privateSearch:
            return "Private Search"
        case .webTrackingProtection:
            return "Web Tracking Protection"
        case .cookiePopupProtection:
            return "Cookie Pop-up Protection"
        case .emailProtection:
            return "Email Protection"
        case .general:
            return UserText.general
        case .sync:
            let isSyncBookmarksPaused = UserDefaults.standard.bool(forKey: UserDefaultsWrapper<Bool>.Key.syncBookmarksPaused.rawValue)
            let isSyncCredentialsPaused = UserDefaults.standard.bool(forKey: UserDefaultsWrapper<Bool>.Key.syncCredentialsPaused.rawValue)
            let syncService = NSApp.delegateTyped.syncService
            let isDataSyncingDisabled = syncService?.featureFlags.contains(.dataSyncing) == false && syncService?.authState == .active
            if isSyncBookmarksPaused || isSyncCredentialsPaused || isDataSyncingDisabled {
                return UserText.sync + " ⚠️"
            }
            return UserText.sync
        case .appearance:
            return UserText.appearance
        case .fireButton:
            return UserText.fireButton
#if NETWORK_PROTECTION
        case .vpn:
            return UserText.vpn
#endif
#if SUBSCRIPTION
        case .subscription:
            return UserText.subscription
#endif
        case .autofill:
            return UserText.autofill
        case .downloads:
            return UserText.downloads
        case .duckPlayer:
            return UserText.duckPlayer
        case .about:
            return UserText.about
        }
    }

    var preferenceIconName: String {
        switch self {
        case .defaultBrowser:
            return "DefaultBrowserIcon"
        case .privateSearch:
            return "PrivateSearchIcon"
        case .webTrackingProtection:
            return "WebTrackingProtectionIcon"
        case .cookiePopupProtection:
            return "CookieProtectionIcon"
        case .emailProtection:
            return "EmailProtectionIcon"
        case .general:
            return "GeneralIcon"
        case .sync:
            return "Sync"
        case .appearance:
            return "Appearance"
        case .fireButton:
            return "FireSettings"
#if NETWORK_PROTECTION
        case .vpn:
            return "VPN"
#endif
#if SUBSCRIPTION
        case .subscription:
            return "Privacy"
#endif
        case .autofill:
            return "Autofill"
        case .downloads:
            return "DownloadsPreferences"
        case .duckPlayer:
            return "DuckPlayerSettings"
        case .about:
            return "About"
        }
    }
}
