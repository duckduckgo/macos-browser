//
//  PreferencesAIChat.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

    struct AIChatView: View {
        @ObservedObject var model: AIChatPreferences

        var body: some View {
            PreferencePane {
                TextMenuTitle(UserText.aiChat)
                PreferencePaneSubSection {
                    VStack(alignment: .leading, spacing: 1) {
                        TextMenuItemCaption(UserText.aiChatPreferencesCaption)
                        TextButton(UserText.aiChatPreferencesLearnMoreButton) {
                            model.openLearnMoreLink()
                        }
                    }
                }

                PreferencePaneSection {
                    if model.shouldShowToolBarShortcutOption {
                        ToggleMenuItem(UserText.aiChatShowInToolbarToggle,
                                       isOn: $model.showShortcutInToolbar)
                    }
                    if model.shouldShowApplicationMenuShortcutOption {
                        ToggleMenuItem(UserText.aiChatShowInApplicationMenuToggle,
                                       isOn: $model.showShortcutInApplicationMenu)
                    }
                }
            }
        }
    }
}
