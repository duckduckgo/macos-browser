//
//  PreferencesPrivateSearchView.swift
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

import AppKit
import Combine
import PreferencesViews
import SwiftUI
import SwiftUIExtensions

extension Preferences {

    struct PrivateSearchView: View {
        @ObservedObject var model: SearchPreferences

        var body: some View {
            PreferencePane("Private Search") {

                // SECTION 1: Private Search
                PreferencePaneSection {
                    ToggleMenuItem("Always On", isOn: .constant(true))
                        .disabled(true)
                    VStack(alignment: .leading, spacing: 0) {
                        TextMenuItemCaption(UserText.privateSearchExplenation)
                        TextButton(UserText.learnMore) {
                            WindowControllersManager.shared.show(url: .privateSearchLearnMore,
                                                                 source: .ui,
                                                                 newTab: true)
                        }
                    }
                }

                // SECTION 2: Search Settings
                PreferencePaneSection("Search Settings") {
                    ToggleMenuItem(UserText.showAutocompleteSuggestions, isOn: $model.showAutocompleteSuggestions)
                }

                // SECTION 3: More Search Settings
                PreferencePaneSection {
                    TextButton("More Search Settings", weight: .semibold) {
                        WindowControllersManager.shared.show(url: .searchSettings,
                                                             source: .ui,
                                                             newTab: true)
                    }
                    TextMenuItemCaption("Customize your search language, region, and more")
                }
            }
        }
    }
}
