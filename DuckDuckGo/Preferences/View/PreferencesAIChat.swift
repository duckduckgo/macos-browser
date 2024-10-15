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

import PreferencesViews
import SwiftUI
import SwiftUIExtensions

extension Preferences {

    struct AIChatView: View {
        @ObservedObject var model: AIChatPreferences

        var body: some View {
            PreferencePane {
                TextMenuTitle("AI Chat")
                PreferencePaneSubSection {
                    VStack(alignment: .leading, spacing: 1) {
                        TextMenuItemCaption("Launch AI Chat faster by adding shortcuts to your browser toolbar or menu")
                        TextButton("Learn More") {
                            model.openLearnMoreLink()
                        }
                    }
                }

                PreferencePaneSection {
                    ToggleMenuItem("Show AI Chat shortcut in browser toolbar", isOn: $model.showShortcutInToolbar)
                    ToggleMenuItem("Show “New AI Chat” in File and application menus", isOn: $model.showShortcutInApplicationMenu)

                }
            }
        }
    }
}
