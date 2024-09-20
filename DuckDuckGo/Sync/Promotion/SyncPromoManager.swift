//
//  SyncPromoManager.swift
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
import BrowserServicesKit
import DDGSync

protocol SyncPromoManaging {
    func shouldPresentPromoFor(_ touchpoint: SyncPromoManager.Touchpoint) -> Bool
    func goToSyncSettings(for touchpoint: SyncPromoManager.Touchpoint)
    func dismissPromoFor(_ touchpoint: SyncPromoManager.Touchpoint)
    func resetPromos()
}

final class SyncPromoManager: SyncPromoManaging {

    enum Touchpoint: String {
        case bookmarks
        case passwords
    }

    public struct SyncPromoManagerNotifications {
        public static let didDismissPromo = NSNotification.Name(rawValue: "com.duckduckgo.syncPromo.didDismiss")
        public static let didGoToSync = NSNotification.Name(rawValue: "com.duckduckgo.syncPromo.didGoToSync")
    }

    public struct Constants {
        public static let syncPromoSourceKey = "source"
        public static let syncPromoBookmarksSource = "promotion_bookmarks"
        public static let syncPromoPasswordsSource = "promotion_passwords"
    }

    private let syncService: DDGSyncing?
    private let privacyConfigurationManager: PrivacyConfigurationManaging
    private let autofillPrefs = AutofillPreferences()

    @UserDefaultsWrapper(key: .syncPromoBookmarksDismissed, defaultValue: nil)
    private var syncPromoBookmarksDismissed: Date?

    @UserDefaultsWrapper(key: .syncPromoPasswordsDismissed, defaultValue: nil)
    private var syncPromoPasswordsDismissed: Date?

    init(syncService: DDGSyncing? = NSApp.delegateTyped.syncService,
         privacyConfigurationManager: PrivacyConfigurationManaging = ContentBlocking.shared.privacyConfigurationManager) {
        self.syncService = syncService
        self.privacyConfigurationManager = privacyConfigurationManager
    }

    func shouldPresentPromoFor(_ touchpoint: Touchpoint) -> Bool {
        guard let syncService = syncService else {
            return false
        }

        switch touchpoint {
        case .bookmarks:
            if privacyConfigurationManager.privacyConfig.isSubfeatureEnabled(SyncPromotionSubfeature.bookmarks),
               privacyConfigurationManager.privacyConfig.isSubfeatureEnabled(SyncSubfeature.level0ShowSync),
               syncService.authState == .inactive,
               syncPromoBookmarksDismissed == nil {
                return true
            }
        case .passwords:
            if privacyConfigurationManager.privacyConfig.isSubfeatureEnabled(SyncPromotionSubfeature.passwords),
               privacyConfigurationManager.privacyConfig.isSubfeatureEnabled(SyncSubfeature.level0ShowSync),
               autofillPrefs.passwordManager == .duckduckgo,
               syncService.authState == .inactive,
               syncPromoPasswordsDismissed == nil {
                return true
            }
        }

        return false
    }

    @MainActor func goToSyncSettings(for touchpoint: Touchpoint) {
        WindowControllersManager.shared.showPreferencesTab(withSelectedPane: .sync)

        var source: String
        switch touchpoint {
        case .bookmarks:
            source = Constants.syncPromoBookmarksSource
        case .passwords:
            source = Constants.syncPromoPasswordsSource
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [self] in
            NotificationCenter.default.post(name: SyncPromoManagerNotifications.didGoToSync, object: self, userInfo: [
                Constants.syncPromoSourceKey: source
            ])
        }
    }

    func dismissPromoFor(_ touchpoint: Touchpoint) {
        switch touchpoint {
        case .bookmarks:
            syncPromoBookmarksDismissed = Date()
            NotificationCenter.default.post(name: SyncPromoManagerNotifications.didDismissPromo, object: nil)
        case .passwords:
            syncPromoPasswordsDismissed = Date()
        }
    }

    func resetPromos() {
        syncPromoBookmarksDismissed = nil
        syncPromoPasswordsDismissed = nil
        NotificationCenter.default.post(name: SyncPromoManagerNotifications.didDismissPromo, object: nil)
    }
}
