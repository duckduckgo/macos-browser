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

import PreferencesUI_macOS
import PixelKit
import SwiftUI
import SwiftUIExtensions

extension Preferences {

    struct DuckPlayerView: View {
        @ObservedObject var model: DuckPlayerPreferences
        /// The ContingencyMessageView may be redrawn multiple times in the onAppear method if the user changes tabs.
        /// This property ensures that the associated action is only triggered once per viewing session, preventing redundant executions.
        @State private var hasFiredSettingsDisplayedPixel = false

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

                if model.shouldDisplayContingencyMessage {
                    PreferencePaneSection {
                        ContingencyMessageView {
                            model.openLearnMoreContingencyURL()
                        }
                        .frame(width: 512)
                        .onAppear {
                            if !hasFiredSettingsDisplayedPixel {
                                PixelKit.fire(NonStandardEvent(GeneralPixel.duckPlayerContingencySettingsDisplayed))
                                hasFiredSettingsDisplayedPixel = true
                            }
                        }
                    }
                }

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
                    .offset(x: PreferencesUI_macOS.Const.pickerHorizontalOffset)

                    TextMenuItemCaption(UserText.duckPlayerExplanation)
                }.disabled(model.shouldDisplayContingencyMessage)

                if model.shouldDisplayAutoPlaySettings || model.isOpenInNewTabSettingsAvailable {
                    PreferencePaneSection(UserText.duckPlayerVideoPreferencesTitle) {

                        if model.shouldDisplayAutoPlaySettings {
                            ToggleMenuItem(UserText.duckPlayerAutoplayPreference, isOn: $model.duckPlayerAutoplay)
                        }

                        if model.isOpenInNewTabSettingsAvailable {
                            ToggleMenuItem(UserText.duckPlayerNewTabPreference, isOn: $model.duckPlayerOpenInNewTab)
                                .disabled(!model.isNewTabSettingsAvailable)
                        }
                    }.disabled(model.shouldDisplayContingencyMessage)
                }

            }
        }
    }
}

private struct ContingencyMessageView: View {
    private enum Copy {
        static let title: String = UserText.duckPlayerContingencyMessageTitle
        static let message: String = UserText.duckPlayerContingencyMessageBody
        static let buttonTitle: String = UserText.duckPlayerContingencyMessageCTA
    }

    private enum Constants {
        static let cornerRadius: CGFloat = 8
        static let imageName: String = "WarningYoutube"
        static let imageSize: CGSize = CGSize(width: 64, height: 48)
    }

    let buttonCallback: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            Image(Constants.imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: Constants.imageSize.width, height: Constants.imageSize.height)

            VStack (alignment: .leading, spacing: 3) {
                Text(Copy.title)
                    .bold()
                Text(Copy.message)
                    .foregroundColor(Color(.blackWhite60))
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    buttonCallback()
                } label: {
                    Text(Copy.buttonTitle)
                }.padding(.top, 15)
            }
        }
        .padding()
          .background(
            ZStack {
                RoundedRectangle(cornerRadius: Constants.cornerRadius)
                    .stroke(Color(.blackWhite10), lineWidth: 1)
                RoundedRectangle(cornerRadius: Constants.cornerRadius)
                    .fill(Color(.blackWhite1))
            }
          )
    }
}

#Preview {
    Group {
        ContingencyMessageView { }
    }.frame(height: 300)
}
