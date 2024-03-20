//
//  PreferencesCookiePopupProtectionView.swift
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

    struct CookiePopupProtectionView: View {
        @ObservedObject var model: CookiePopupProtectionPreferences

        var body: some View {
            PreferencePane(UserText.cookiePopUpProtection, spacing: 4) {

                // SECTION 1: Status Indicator
                PreferencePaneSection {
                    StatusIndicatorView(status: model.isAutoconsentEnabled ? .on : .off, isLarge: true)
                }

                // SECTION 2: Description
                PreferencePaneSection {
                    VStack(alignment: .leading, spacing: 1) {
                        TextMenuItemCaption(UserText.autoconsentExplanation)
                        TextButton(UserText.learnMore) {
                            model.openNewTab(with: .cookieConsentPopUpManagement)
                        }
                    }
                }

                // SECTION 3: Search Settings
                PreferencePaneSection {
                    ToggleMenuItem(UserText.autoconsentCheckboxTitle, isOn: $model.isAutoconsentEnabled)
                }
            }
        }
    }
}
