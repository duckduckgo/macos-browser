//
//  AccessibilityPreferences.swift
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
import AppKit
import Bookmarks
import Common

protocol AccessibilityPreferencesPersistor {
    var defaultPageZoom: CGFloat { get set }
}

struct AccessibilityPreferencesUserDefaultsPersistor: AccessibilityPreferencesPersistor {
    @UserDefaultsWrapper(key: .defaultPageZoom, defaultValue: DefaultZoomValue.percent100.rawValue)
    var defaultPageZoom: CGFloat
}

enum DefaultZoomValue: CGFloat, CaseIterable {
    case percent50 = 0.5
    case percent75 = 0.75
    case percent85 = 0.85
    case percent100 = 1.0
    case percent115 = 1.15
    case percent125 = 1.25
    case percent150 = 1.50
    case percent175 = 1.75
    case percent200 = 2.0
    case percent250 = 2.5
    case percent300 = 3.0

    var displayString: String {
        let percentage = (self.rawValue * 100).rounded()
        return String(format: "%.0f%%", percentage)
    }

    var index: Int {DefaultZoomValue.allCases.firstIndex(of: self) ?? 3}
}

final class AccessibilityPreferences: ObservableObject {
    static let shared = AccessibilityPreferences()

    @Published var defaultPageZoom: DefaultZoomValue {
        didSet {
            persistor.defaultPageZoom = defaultPageZoom.rawValue
        }
    }

    init(persistor: AccessibilityPreferencesPersistor = AccessibilityPreferencesUserDefaultsPersistor()) {
        self.persistor = persistor
        defaultPageZoom =  .init(rawValue: persistor.defaultPageZoom) ?? .percent100
    }

    private var persistor: AccessibilityPreferencesPersistor
}
