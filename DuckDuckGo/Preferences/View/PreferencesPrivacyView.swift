//
//  PreferencesPrivacyView.swift
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

import PreferencesViews
import SwiftUI
import SwiftUIExtensions

extension Preferences {

    struct PrivacyView: View {
        @ObservedObject var model: PrivacyPreferencesModel

        var body: some View {
            PreferencePane(UserText.privacy) {

                // SECTION 1: Cookie Consent Pop-ups
                PreferencePaneSection(UserText.autoconsentSettingsTitle) {

                    ToggleMenuItem(UserText.autoconsentCheckboxTitle, isOn: $model.isAutoconsentEnabled)
                    VStack(alignment: .leading, spacing: 0) {
                        TextMenuItemCaption(UserText.autoconsentExplanation)
                        TextButton(UserText.learnMore) {
                            model.openURL(.cookieConsentPopUpManagement)
                        }
                    }
                }

                // SECTION 2: Fireproof Site
                PreferencePaneSection(UserText.fireproofSites) {

                    PreferencePaneSubSection {
                        ToggleMenuItem(UserText.fireproofCheckboxTitle, isOn: $model.isLoginDetectionEnabled)
                        VStack(alignment: .leading, spacing: 0) {
                            TextMenuItemCaption(UserText.fireproofExplanation)
                            TextButton(UserText.learnMore) {
                                model.openURL(.theFireButton)
                            }
                        }
                    }

                    PreferencePaneSubSection {
                        Button(UserText.manageFireproofSites) {
                            model.presentManageFireproofSitesDialog()
                        }
                    }
                }

            }
        }
    }
}
