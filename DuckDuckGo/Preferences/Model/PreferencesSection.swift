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
import Subscription
import BrowserServicesKit

struct PreferencesSection: Hashable, Identifiable {
    let id: PreferencesSectionIdentifier
    let panes: [PreferencePaneIdentifier]

    @MainActor
    static func defaultSections(includingDuckPlayer: Bool,
                                includingSync: Bool,
                                includingVPN: Bool,
                                includingAIChat: Bool) -> [PreferencesSection] {
        let privacyPanes: [PreferencePaneIdentifier] = [
            .defaultBrowser, .privateSearch, .webTrackingProtection, .cookiePopupProtection, .emailProtection
        ]

        let regularPanes: [PreferencePaneIdentifier] = {
            var panes: [PreferencePaneIdentifier] = [.general, .appearance, .autofill, .accessibility, .dataClearing]

            if includingSync {
                panes.insert(.sync, at: 1)
            }

            if includingDuckPlayer {
                panes.append(.duckPlayer)
            }

            if includingAIChat {
                panes.append(.aiChat)
            }

            return panes
        }()

#if APPSTORE
        // App Store guidelines don't allow references to other platforms, so the Mac App Store build omits the otherPlatforms section.
        let otherPanes: [PreferencePaneIdentifier] = [.about]
#else
        let otherPanes: [PreferencePaneIdentifier] = [.about, .otherPlatforms]
#endif

        var sections: [PreferencesSection] = [
            .init(id: .privacyProtections, panes: privacyPanes),
            .init(id: .regularPreferencePanes, panes: regularPanes),
            .init(id: .about, panes: otherPanes)
        ]

        let subscriptionManager = Application.appDelegate.subscriptionManager
        let platform = subscriptionManager.currentEnvironment.purchasePlatform
        var shouldHidePrivacyProDueToNoProducts = platform == .appStore && subscriptionManager.canPurchase == false

        if subscriptionManager.accountManager.isUserAuthenticated {
            shouldHidePrivacyProDueToNoProducts = false
        }

        if !shouldHidePrivacyProDueToNoProducts {
            var subscriptionPanes: [PreferencePaneIdentifier] = [.subscription]

            if includingVPN {
                subscriptionPanes.append(.vpn)
            }

            sections.insert(.init(id: .privacyPro, panes: subscriptionPanes), at: 1)
        }

        return sections
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
            return UserText.privacyProtections
        case .privacyPro:
            return nil
        case .regularPreferencePanes:
            return UserText.mainSettings
        case .about:
            return nil
        }
    }

}

enum PreferencePaneIdentifier: String, Equatable, Hashable, Identifiable, CaseIterable {
    case defaultBrowser
    case privateSearch
    case webTrackingProtection
    case cookiePopupProtection
    case emailProtection

    case general
    case sync
    case appearance
    case dataClearing
    case vpn
    case subscription
    case autofill
    case accessibility
    case duckPlayer = "duckplayer"
    case otherPlatforms = "https://duckduckgo.com/app?origin=funnel_app_macos"
    case aiChat = "aichat"
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
            return UserText.defaultBrowser
        case .privateSearch:
            return UserText.privateSearch
        case .webTrackingProtection:
            return UserText.webTrackingProtection
        case .cookiePopupProtection:
            return UserText.cookiePopUpProtection
        case .emailProtection:
            return UserText.emailProtectionPreferences
        case .general:
            return UserText.general
        case .sync:
            let isSyncBookmarksPaused = UserDefaults.standard.bool(forKey: UserDefaultsWrapper<Bool>.Key.syncBookmarksPaused.rawValue)
            let isSyncCredentialsPaused = UserDefaults.standard.bool(forKey: UserDefaultsWrapper<Bool>.Key.syncCredentialsPaused.rawValue)
            let isSyncPaused = UserDefaults.standard.bool(forKey: UserDefaultsWrapper<Bool>.Key.syncIsPaused.rawValue)
            let syncService = NSApp.delegateTyped.syncService
            let isDataSyncingDisabled = syncService?.featureFlags.contains(.dataSyncing) == false && syncService?.authState == .active
            if isSyncPaused || isSyncBookmarksPaused || isSyncCredentialsPaused || isDataSyncingDisabled {
                return UserText.sync + " ⚠️"
            }
            return UserText.sync
        case .appearance:
            return UserText.appearance
        case .dataClearing:
            return UserText.dataClearing
        case .vpn:
            return UserText.vpn
        case .subscription:
            return UserText.subscription
        case .autofill:
            return UserText.passwordManagementTitle
        case .accessibility:
            return UserText.accessibility
        case .duckPlayer:
            return UserText.duckPlayer
        case .aiChat:
            return UserText.aiChat
        case .about:
            return UserText.about
        case .otherPlatforms:
            return UserText.duckduckgoOnOtherPlatforms
        }
    }

    var preferenceIconName: String {
        switch self {
        case .defaultBrowser:
            return "DefaultBrowser"
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
        case .dataClearing:
            return "FireSettings"
        case .vpn:
            return "VPN"
        case .subscription:
            return "PrivacyPro"
        case .autofill:
            return "Autofill"
        case .accessibility:
            return "Accessibility"
        case .duckPlayer:
            return "DuckPlayerSettings"
        case .about:
            return "About"
        case .otherPlatforms:
            return "OtherPlatformsPreferences"
        case .aiChat:
            return "AiChatPreferences"
        }
    }
}
