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
}

protocol PinningManager {
    
    func togglePinning(for view: PinnableView)
    func isPinned(_ view: PinnableView) -> Bool
    
}

final class LocalPinningManager: PinningManager {

    static let shared = LocalPinningManager()
    
    static let pinnedViewChangedNotificationViewTypeKey = "pinning.pinnedViewChanged.viewType"
    static let pinnedViewChangedNotificationIsBeingAdded = "pinning.pinnedViewChanged.isBeingAdded"
    
    @UserDefaultsWrapper(key: .pinnedViews, defaultValue: [])
    private var pinnedViewStrings: [String]

    func togglePinning(for view: PinnableView) {
        let didPinView: Bool
        
        if isPinned(view) {
            pinnedViewStrings.removeAll(where: { $0 == view.rawValue })
            didPinView = false
        } else {
            pinnedViewStrings.append(view.rawValue)
            didPinView = true
        }
        
        NotificationCenter.default.post(name: .PinnedViewsChanged, object: nil, userInfo: [
            Self.pinnedViewChangedNotificationViewTypeKey: view.rawValue,
            Self.pinnedViewChangedNotificationIsBeingAdded: didPinView
        ])
    }
    
    func isPinned(_ view: PinnableView) -> Bool {
        return pinnedViewStrings.contains(view.rawValue)
    }

}

// MARK: - NSNotification

extension NSNotification.Name {

    static let PinnedViewsChanged = NSNotification.Name("pinning.pinnedViewsChanged")

}
