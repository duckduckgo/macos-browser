//
//  PreferencesPrivatePlayerView.swift
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

    struct PrivatePlayerView: View {
        @ObservedObject var model: PrivatePlayerPreferences

        var privatePlayerModeBinding: Binding<PrivatePlayerMode> {
            .init {
                model.privatePlayerMode
            } set: { newValue in
                model.privatePlayerMode = newValue
            }
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {

                // TITLE
                TextMenuTitle(text: UserText.privatePlayer)

                PreferencePaneSection {
                    Picker(selection: privatePlayerModeBinding, content: {
                        Text(UserText.privatePlayerAlwaysOpenInPlayer)
                            .padding(.bottom, 4)
                            .tag(PrivatePlayerMode.enabled)

                        Text(UserText.privatePlayerShowPlayerButtons)
                            .padding(.bottom, 4)
                            .tag(PrivatePlayerMode.alwaysAsk)

                        Text(UserText.privatePlayerOff)
                            .padding(.bottom, 4)
                            .tag(PrivatePlayerMode.disabled)

                    }, label: {})
                    .pickerStyle(.radioGroup)
                    .offset(x: Const.pickerHorizontalOffset)

                    TextMenuItemCaption(text: UserText.privatePlayerExplanation)
                }
            }
        }
    }
}
