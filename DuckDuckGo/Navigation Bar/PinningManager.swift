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

    var autofillPinned = false
    var bookmarksPinned = false
    
    @UserDefaultsWrapper(key: .pinnedViews, defaultValue: [])
    private var pinnedViewStrings: [String]
    
    private var pinnedViews: [PinnableView] {
        return pinnedViewStrings.compactMap(PinnableView.init(rawValue:))
    }

    func togglePinning(for view: PinnableView) {
        if isPinned(view) {
            pinnedViewStrings.removeAll(where: { $0 == view.rawValue })
        } else {
            pinnedViewStrings.append(view.rawValue)
        }
    }
    
    func isPinned(_ view: PinnableView) -> Bool {
        return pinnedViewStrings.contains(view.rawValue)
    }

}
