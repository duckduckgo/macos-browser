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
            VStack(alignment: .leading, spacing: 0) {

                // TITLE
                TextMenuTitle(UserText.privacy)

                // SECTION 1: Web Tracking Protection Section
                PreferencePaneSection {
                    TextMenuItemHeader(UserText.webTrackingProtectionSettingsTitle)
                    VStack(alignment: .leading, spacing: 6) {
                        TextMenuItemCaption(UserText.webTrackingProtectionExplenation)
                        TextButton(UserText.learnMore) {
                            model.openURL(.webTrackingProtection)
                        }
                    }
                }

                // SECTION 2: Cookie Consent Pop-ups
                PreferencePaneSection {
                    TextMenuItemHeader(UserText.autoconsentSettingsTitle)
                    ToggleMenuItem(UserText.autoconsentCheckboxTitle, isOn: $model.isAutoconsentEnabled)
                    VStack(alignment: .leading, spacing: 6) {
                        TextMenuItemCaption(UserText.autoconsentExplanation)
                        TextButton(UserText.learnMore) {
                            model.openURL(.cookieConsentPopUpManagement)
                        }
                    }
                }

                // SECTION 3: Fireproof Site
                PreferencePaneSection {
                    TextMenuItemHeader(UserText.fireproofSites)
                    ToggleMenuItem(UserText.fireproofCheckboxTitle, isOn: $model.isLoginDetectionEnabled)
                    VStack(alignment: .leading, spacing: 6) {
                        TextMenuItemCaption(UserText.fireproofExplanation)
                        TextButton(UserText.learnMore) {
                            model.openURL(.theFireButton)
                        }
                    }
                    Button(UserText.manageFireproofSites) {
                        model.presentManageFireproofSitesDialog()
                    }
                }

                // SECTION 4: Global privacy control
                PreferencePaneSection {
                    TextMenuItemHeader(UserText.gpcSettingsTitle)
                    ToggleMenuItem(UserText.gpcCheckboxTitle, isOn: $model.isGPCEnabled)
                    VStack(alignment: .leading, spacing: 6) {
                        TextMenuItemCaption(UserText.gpcExplanation)
                        TextButton(UserText.learnMore) {
                            model.openURL(.gpcLearnMore)
                        }
                    }
                }
            }
        }
    }
}
