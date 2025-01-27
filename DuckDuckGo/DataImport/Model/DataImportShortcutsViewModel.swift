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
import BrowserServicesKit

final class DataImportShortcutsViewModel: ObservableObject {
    typealias DataType = DataImport.DataType

    let dataTypes: Set<DataType>?
    private let prefs: AppearancePreferences
    private let pinningManager: LocalPinningManager

    @Published var showBookmarksBarStatus: Bool {
        didSet {
            prefs.showBookmarksBar = showBookmarksBarStatus
        }
    }

    @Published var showPasswordsPinnedStatus: Bool {
        didSet {
            if showPasswordsPinnedStatus {
                pinningManager.pin(.autofill)
                NotificationCenter.default.post(name: .passwordsAutoPinned, object: nil)
            } else {
                pinningManager.unpin(.autofill)
            }
        }
    }

    init(dataTypes: Set<DataType>? = nil, prefs: AppearancePreferences = AppearancePreferences.shared, pinningManager: LocalPinningManager = LocalPinningManager.shared) {
        self.dataTypes = dataTypes
        self.prefs = prefs
        self.pinningManager = pinningManager

        showBookmarksBarStatus = prefs.showBookmarksBar
        showPasswordsPinnedStatus = pinningManager.isPinned(.autofill)
    }
}
