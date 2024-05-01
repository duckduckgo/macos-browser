//
//  DataImportShortcutsViewModel.swift
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
import SwiftUI

final class DataImportShortcutsViewModel: ObservableObject {

    let prefs: AppearancePreferences
    let pinningManager: LocalPinningManager

    @Published var showBookmarksBarStatusBool: Bool {
        didSet {
            prefs.showBookmarksBar = showBookmarksBarStatusBool
        }
    }

    @Published var showPasswordsPinnedStatusBool: Bool {
        didSet {
            if showPasswordsPinnedStatusBool {
                pinningManager.pin(.autofill)
                NotificationCenter.default.post(name: .passwordsAutoPinned, object: nil)
            } else {
                pinningManager.unpin(.autofill)
            }
        }
    }

    init(prefs: AppearancePreferences = AppearancePreferences.shared, pinningManager: LocalPinningManager = LocalPinningManager.shared) {
        self.prefs = prefs
        self.pinningManager = pinningManager

        showBookmarksBarStatusBool = prefs.showBookmarksBar
        showPasswordsPinnedStatusBool = pinningManager.isPinned(.autofill)
    }
}
