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

import SwiftUI
import SwiftUIExtensions

extension Preferences {

    struct PrivacyView: View {
        @ObservedObject var model: PrivacyPreferencesModel

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {

                // TITLE
                TextMenuTitle(text: UserText.privacy)

                // SECTION 1: Web Tracking Protection Section
                PreferencePaneSection {
                    TextMenuItemHeader(text: UserText.webTrackingProtectionSettingsTitle)
                    TextMenuItemCaption(text: UserText.webTrackingProtectionExplenation)
                    TextButton(UserText.learnMore) {
                        model.openURL(.webTrackingProtection)
                    }
                }

                // SECTION 2: Cookie Consent Pop-ups
                PreferencePaneSection {
                    TextMenuItemHeader(text: UserText.autoconsentSettingsTitle)
                    ToggleMenuItem(title: UserText.autoconsentCheckboxTitle, isOn: $model.isAutoconsentEnabled)
                    TextMenuItemCaption(text: UserText.autoconsentExplanation)
                    TextButton(UserText.learnMore) {
                        model.openURL(.cookieConsentPopUpManagement)
                    }
                }

                // SECTION 3: Fireproof Site
                PreferencePaneSection {
                    TextMenuItemHeader(text: UserText.fireproofSites)
                    ToggleMenuItem(title: UserText.fireproofCheckboxTitle, isOn: $model.isLoginDetectionEnabled)
                    TextMenuItemCaption(text: UserText.fireproofExplanation)
                    TextButton(UserText.learnMore) {
                        model.openURL(.theFireButton)
                    }
                    Button(UserText.manageFireproofSites) {
                        model.presentManageFireproofSitesDialog()
                    }
                }

                // SECTION 4: Global privacy control
                PreferencePaneSection {
                    TextMenuItemHeader(text: UserText.gpcSettingsTitle)
                    ToggleMenuItem(title: UserText.gpcCheckboxTitle, isOn: $model.isGPCEnabled)
                    TextMenuItemCaption(text: UserText.gpcExplanation)
                    TextButton(UserText.learnMore) {
                        model.openURL(.gpcLearnMore)
                    }
                }
            }
        }
    }
}
