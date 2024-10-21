//
//  PinningManager.swift
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
import NetworkProtection

enum PinnableView: String {
    case autofill
    case bookmarks
    case downloads
    case homeButton
    case networkProtection
    case aiChat
}

protocol PinningManager {

    func togglePinning(for view: PinnableView)
    func isPinned(_ view: PinnableView) -> Bool
    func wasManuallyToggled(_ view: PinnableView) -> Bool
    func pin(_ view: PinnableView)
    func unpin(_ view: PinnableView)
    func shortcutTitle(for view: PinnableView) -> String
}

final class LocalPinningManager: PinningManager {

    static let shared = LocalPinningManager(networkProtectionFeatureActivation: NetworkProtectionKeychainTokenStore())

    static let pinnedViewChangedNotificationViewTypeKey = "pinning.pinnedViewChanged.viewType"

    @UserDefaultsWrapper(key: .pinnedViews, defaultValue: [])
    private var pinnedViewStrings: [String]

    @UserDefaultsWrapper(key: .manuallyToggledPinnedViews, defaultValue: [])
    private var manuallyToggledPinnedViewsStrings: [String]

    private let networkProtectionFeatureActivation: NetworkProtectionFeatureActivation

    init(networkProtectionFeatureActivation: NetworkProtectionFeatureActivation) {
        self.networkProtectionFeatureActivation = networkProtectionFeatureActivation
    }

    func togglePinning(for view: PinnableView) {
        flagAsManuallyToggled(view)

        if isPinned(view) {
            pinnedViewStrings.removeAll(where: { $0 == view.rawValue })
        } else {
            pinnedViewStrings.append(view.rawValue)
        }

        NotificationCenter.default.post(name: .PinnedViewsChanged, object: nil, userInfo: [
            Self.pinnedViewChangedNotificationViewTypeKey: view.rawValue
        ])
    }

    /// Do not call this for user-initiated toggling.  This is only meant to be used for scenarios in which certain conditions
    /// may require a view to be pinned.
    ///
    func pin(_ view: PinnableView) {
        guard !isPinned(view) else {
            return
        }

        pinnedViewStrings.append(view.rawValue)

        NotificationCenter.default.post(name: .PinnedViewsChanged, object: nil, userInfo: [
            Self.pinnedViewChangedNotificationViewTypeKey: view.rawValue
        ])
    }

    /// Do not call this for user-initiated toggling.  This is only meant to be used for scenarios in which certain conditions
    /// may require a view to be unpinned.
    ///
    func unpin(_ view: PinnableView) {
        guard isPinned(view) else {
            return
        }

        manuallyToggledPinnedViewsStrings.removeAll(where: { $0 == view.rawValue })
        pinnedViewStrings.removeAll(where: { $0 == view.rawValue })

        NotificationCenter.default.post(name: .PinnedViewsChanged, object: nil, userInfo: [
            Self.pinnedViewChangedNotificationViewTypeKey: view.rawValue
        ])
    }

    func isPinned(_ view: PinnableView) -> Bool {
        return pinnedViewStrings.contains(view.rawValue)
    }

    func shortcutTitle(for view: PinnableView) -> String {
        switch view {
        case .autofill: return isPinned(.autofill) ? UserText.hideAutofillShortcut : UserText.showAutofillShortcut
        case .bookmarks: return isPinned(.bookmarks) ? UserText.hideBookmarksShortcut : UserText.showBookmarksShortcut
        case .downloads: return isPinned(.downloads) ? UserText.hideDownloadsShortcut : UserText.showDownloadsShortcut
        case .homeButton: return ""
        case .networkProtection:
            return isPinned(.networkProtection) ? UserText.hideNetworkProtectionShortcut : UserText.showNetworkProtectionShortcut
        case .aiChat:
            return isPinned(.aiChat) ? UserText.hideAIChatShortcut : UserText.showAIChatShortcut

        }
    }

    // MARK: - Recording Manual Toggling

    /// This method is useful for knowing if the view was manually toggled.
    /// It's particularly useful for initializing a pin to a certain value at a certain point during the execution of code,
    /// only if the user hasn't explicitly specified a desired state.
    /// As an example: this is used in the VPN for pinning the icon to the navigation bar the first time the
    /// feature is enabled.
    ///
    func wasManuallyToggled(_ view: PinnableView) -> Bool {
        manuallyToggledPinnedViewsStrings.contains(view.rawValue)
    }

    /// Flags a view as having been manually pinned / unpinned by the user.
    ///
    private func flagAsManuallyToggled(_ view: PinnableView) {
        var set = Set(manuallyToggledPinnedViewsStrings)
        set.insert(view.rawValue)
        manuallyToggledPinnedViewsStrings = Array(set)
    }
}

// MARK: - NSNotification

extension NSNotification.Name {

    static let PinnedViewsChanged = NSNotification.Name("pinning.pinnedViewsChanged")

}
