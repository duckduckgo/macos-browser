//
//  SearchPreferences.swift
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
import PixelKit

protocol SearchPreferencesPersistor {
    var showAutocompleteSuggestions: Bool { get set }
}

struct SearchPreferencesUserDefaultsPersistor: SearchPreferencesPersistor {
    @UserDefaultsWrapper(key: .showAutocompleteSuggestions, defaultValue: true)
    var showAutocompleteSuggestions: Bool
}

final class SearchPreferences: ObservableObject, PreferencesTabOpening {

    static let shared = SearchPreferences()

    @Published var showAutocompleteSuggestions: Bool {
        didSet {
            persistor.showAutocompleteSuggestions = showAutocompleteSuggestions
            PixelKit.fire(showAutocompleteSuggestions ? GeneralPixel.autocompleteToggledOn : GeneralPixel.autocompleteToggledOff)
        }
    }

    init(persistor: SearchPreferencesPersistor = SearchPreferencesUserDefaultsPersistor()) {
        self.persistor = persistor
        showAutocompleteSuggestions = persistor.showAutocompleteSuggestions
    }

    private var persistor: SearchPreferencesPersistor
}

protocol PreferencesTabOpening {

    func openNewTab(with url: URL)

}

extension PreferencesTabOpening {

    @MainActor
    func openNewTab(with url: URL) {
        WindowControllersManager.shared.show(url: url, source: .ui, newTab: true)
    }

    @MainActor
    func show(url: URL) {
        WindowControllersManager.shared.show(url: url, source: .ui, newTab: false)
    }

}
