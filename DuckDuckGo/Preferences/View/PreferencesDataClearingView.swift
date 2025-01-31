//
//  PreferencesDataClearingView.swift
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

import PreferencesUI_macOS
import SwiftUI
import SwiftUIExtensions

extension Preferences {

    struct DataClearingView: View {
        @ObservedObject var model: DataClearingPreferences

        var body: some View {
            PreferencePane(UserText.dataClearing) {

                // SECTION 1: Automatically Clear Data
                PreferencePaneSection(UserText.autoClear) {

                    PreferencePaneSubSection {
                        ToggleMenuItem(UserText.automaticallyClearData, isOn: $model.isAutoClearEnabled)
                        ToggleMenuItem(UserText.warnBeforeQuit,
                                       isOn: $model.isWarnBeforeClearingEnabled)
                        .disabled(!model.isAutoClearEnabled)
                        .padding(.leading, 16)
                    }

                }

                // SECTION 2: Fireproof Site
                PreferencePaneSection(UserText.fireproofSites) {

                    PreferencePaneSubSection {
                        ToggleMenuItem(UserText.fireproofCheckboxTitle, isOn: $model.isLoginDetectionEnabled)
                        VStack(alignment: .leading, spacing: 1) {
                            TextMenuItemCaption(UserText.fireproofExplanation)
                            TextButton(UserText.learnMore) {
                                model.openNewTab(with: .theFireButton)
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
