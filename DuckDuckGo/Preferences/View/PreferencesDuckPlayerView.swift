//
//  PreferencesDuckPlayerView.swift
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
import PixelKit
import SwiftUI
import SwiftUIExtensions

extension Preferences {

    struct DuckPlayerView: View {
        @ObservedObject var model: DuckPlayerPreferences

        var duckPlayerModeBinding: Binding<DuckPlayerMode> {
            .init {
                model.duckPlayerMode
            } set: { newValue in
                model.duckPlayerMode = newValue
                switch model.duckPlayerMode {
                case .enabled:
                    PixelKit.fire(GeneralPixel.duckPlayerSettingAlwaysSettings)
                case .alwaysAsk:
                    PixelKit.fire(GeneralPixel.duckPlayerSettingBackToDefault)
                case .disabled:
                    PixelKit.fire(GeneralPixel.duckPlayerSettingNeverSettings)
                }
            }
        }

        var body: some View {
            PreferencePane {

                // TITLE
                TextMenuTitle(UserText.duckPlayer)

                PreferencePaneSection {
                    Picker(selection: duckPlayerModeBinding, content: {
                        Text(UserText.duckPlayerAlwaysOpenInPlayer)
                            .padding(.bottom, 4)
                            .tag(DuckPlayerMode.enabled)

                        Text(UserText.duckPlayerShowPlayerButtons)
                            .padding(.bottom, 4)
                            .tag(DuckPlayerMode.alwaysAsk)

                        Text(UserText.duckPlayerOff)
                            .padding(.bottom, 4)
                            .tag(DuckPlayerMode.disabled)

                    }, label: {})
                    .pickerStyle(.radioGroup)
                    .offset(x: PreferencesViews.Const.pickerHorizontalOffset)

                    TextMenuItemCaption(UserText.duckPlayerExplanation)
                }
                
                // Auto Play
                if model.shouldDisplayAutoPlaySettings {
                    PreferencePaneSection(UserText.duckPlayerAutoplayTitle) {
                        ToggleMenuItem(UserText.duckPlayerAutoplayPreference, isOn: $model.autoplayEnabled)
                    }
                }
            }
        }
    }
}
