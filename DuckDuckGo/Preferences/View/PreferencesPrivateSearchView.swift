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
            PreferencePane("Private Search", spacing: 20) {

                // Status Indicator
                StatusIndicatorView(status: .alwaysOn, isLarge: true).padding(.top, -16)

                // SECTION 1: Description
                PreferencePaneSection {
                    VStack(alignment: .leading, spacing: 1) {
                        TextMenuItemCaption(UserText.privateSearchExplenation)
                        TextButton(UserText.learnMore) {
                            WindowControllersManager.shared.show(url: .privateSearchLearnMore,
                                                                 source: .ui,
                                                                 newTab: true)
                        }
                    }
                }

                // SECTION 2: Search Settings
                PreferencePaneSection {
                    ToggleMenuItem(UserText.showAutocompleteSuggestions, isOn: $model.showAutocompleteSuggestions)
                }
            }
        }
    }
}

extension Preferences {

    //!TODO REMOVE
    struct DescriptionView: View {
        let imageName: String
        let header: String
        let description: String
        let learnMoreUrl: URL
        let status: StatusIndicator

        var body: some View {
            VStack(alignment: .center, spacing: 16) {
                Image(imageName)
                VStack(alignment: .center, spacing: 4) {
                    Text(header)
                    StatusIndicatorView(status: status)
                }
                VStack(alignment: .center, spacing: 1) {
                    Text(description)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    TextButton(UserText.learnMore) {
                        WindowControllersManager.shared.show(url: learnMoreUrl,
                                                             source: .ui,
                                                             newTab: true)
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 254)
            .roundedBorder()
        }
    }
}
