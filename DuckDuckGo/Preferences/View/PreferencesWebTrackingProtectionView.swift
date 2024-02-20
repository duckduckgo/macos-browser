//
//  PreferencesWebTrackingProtectionView.swift
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

    struct WebTrackingProtectionView: View {
        @ObservedObject var model: WebTrackingProtectionPreferences

        var body: some View {
            PreferencePane("Web Tracking Protection") {

                // SECTION 1: Web Tracking Protection Section
                PreferencePaneSection {
                    ToggleMenuItem("Always On", isOn: .constant(true))
                        .disabled(true)
                    VStack(alignment: .leading, spacing: 0) {
                        TextMenuItemCaption(UserText.webTrackingProtectionExplanation)
                        TextButton(UserText.learnMore) {
                            WindowControllersManager.shared.show(url: .webTrackingProtection,
                                                                 source: .ui,
                                                                 newTab: true)
                        }
                    }
                }

                // SECTION 2: Global privacy control
                PreferencePaneSection(UserText.gpcSettingsTitle) {

                    ToggleMenuItem(UserText.gpcCheckboxTitle, isOn: $model.isGPCEnabled)
                    VStack(alignment: .leading, spacing: 0) {
                        TextMenuItemCaption(UserText.gpcExplanation)
                        TextButton(UserText.learnMore) {
                            WindowControllersManager.shared.show(url: .gpcLearnMore,
                                                                 source: .ui,
                                                                 newTab: true)
                        }
                    }
                }
            }
        }
    }
}
