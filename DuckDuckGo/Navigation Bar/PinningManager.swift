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

enum PinnableView: String {
    case autofill
    case bookmarks
    case downloads
}

protocol PinningManager {

    func togglePinning(for view: PinnableView)
    func isPinned(_ view: PinnableView) -> Bool

}

final class LocalPinningManager: PinningManager {

    static let shared = LocalPinningManager()

    static let pinnedViewChangedNotificationViewTypeKey = "pinning.pinnedViewChanged.viewType"

    @UserDefaultsWrapper(key: .pinnedViews, defaultValue: [])
    private var pinnedViewStrings: [String]

    func togglePinning(for view: PinnableView) {
        if isPinned(view) {
            pinnedViewStrings.removeAll(where: { $0 == view.rawValue })
        } else {
            pinnedViewStrings.append(view.rawValue)
        }

        NotificationCenter.default.post(name: .PinnedViewsChanged, object: nil, userInfo: [
            Self.pinnedViewChangedNotificationViewTypeKey: view.rawValue
        ])
    }

    func isPinned(_ view: PinnableView) -> Bool {
        return pinnedViewStrings.contains(view.rawValue)
    }

    func toggleShortcutInterfaceTitle(for view: PinnableView) -> String {
        switch view {
        case .autofill: return isPinned(.autofill) ? UserText.hideAutofillShortcut : UserText.showAutofillShortcut
        case .bookmarks: return isPinned(.bookmarks) ? UserText.hideBookmarksShortcut : UserText.showBookmarksShortcut
        case .downloads: return isPinned(.downloads) ? UserText.hideDownloadsShortcut : UserText.showDownloadsShortcut
        }
    }

}

// MARK: - NSNotification

extension NSNotification.Name {

    static let PinnedViewsChanged = NSNotification.Name("pinning.pinnedViewsChanged")

}
