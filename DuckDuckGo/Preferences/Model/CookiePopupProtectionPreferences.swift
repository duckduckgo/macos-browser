//
//  CookiePopupProtectionPreferences.swift
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

protocol CookiePopupProtectionPreferencesPersistor {
    var autoconsentEnabled: Bool { get set }
}

struct CookiePopupProtectionPreferencesUserDefaultsPersistor: CookiePopupProtectionPreferencesPersistor {

    @UserDefaultsWrapper(key: .autoconsentEnabled, defaultValue: true)
    var autoconsentEnabled: Bool

}

final class CookiePopupProtectionPreferences: ObservableObject, PreferencesTabOpening {

    static let shared = CookiePopupProtectionPreferences()

    @Published
    var isAutoconsentEnabled: Bool {
        didSet {
            persistor.autoconsentEnabled = isAutoconsentEnabled
        }
    }

    init(persistor: CookiePopupProtectionPreferencesPersistor = CookiePopupProtectionPreferencesUserDefaultsPersistor()) {
        self.persistor = persistor
        isAutoconsentEnabled = persistor.autoconsentEnabled
    }

    private var persistor: CookiePopupProtectionPreferencesPersistor
}
