//
//  PreferencesAppearanceView.swift
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

    struct ThemeButton: View {
        let title: String
        let imageName: String
        @Binding var isSelected: Bool

        var body: some View {
            VStack {
                Button(action: { isSelected.toggle() }) {
                    VStack(spacing: 2) {
                        Image(imageName)
                            .padding(2)
                            .background(selectionBackground)
                        Text(title)
                    }
                }
                .padding(.horizontal, 2)
                .buttonStyle(.plain)
            }
        }

        @ViewBuilder
        private var selectionBackground: some View {
            if isSelected {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color("LinkBlueColor"), lineWidth: 2)
            }
        }

    }

    struct ThemePicker: View {
        @EnvironmentObject var model: AppearancePreferences

        var body: some View {
            HStack(spacing: 24) {
                ForEach(ThemeName.allCases, id: \.self) { theme in
                    ThemeButton(
                        title: theme.displayName,
                        imageName: theme.imageName,
                        isSelected: isThemeSelected(theme)
                    )
                }
            }
        }

        private func isThemeSelected(_ theme: ThemeName) -> Binding<Bool> {
            .init(
                get: {
                    model.currentThemeName == theme
                },
                set: { isSelected in
                    if isSelected {
                        model.currentThemeName = theme
                    }
                }
            )
        }
    }

    struct AppearanceView: View {
        @ObservedObject var model: AppearancePreferences

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                Text(UserText.appearance)
                    .font(Const.Fonts.preferencePaneTitle)

                PreferencePaneSection {
                    Text(UserText.theme)
                        .font(Const.Fonts.preferencePaneSectionHeader)
                    ThemePicker()
                        .environmentObject(model)
                }

                PreferencePaneSection {
                    Text(UserText.addressBar)
                        .font(Const.Fonts.preferencePaneSectionHeader)
                    Toggle(UserText.showFullWebsiteAddress, isOn: $model.showFullURL)
                    Toggle(UserText.showAutocompleteSuggestions, isOn: $model.showAutocompleteSuggestions)
                }

                PreferencePaneSection {
                    Text(UserText.zoomSettingTitle)
                        .font(Const.Fonts.preferencePaneSectionHeader)
                    HStack {
                        Text(UserText.zoomPickerTitle)
                        NSPopUpButtonView(selection: $model.defaultPageZoom) {
                            let button = NSPopUpButton()
                            button.setContentHuggingPriority(.defaultHigh, for: .horizontal)

                            for value in DefaultZoomValues.allCases {
                                let item = button.menu?.addItem(withTitle: value.displayString, action: nil, keyEquivalent: "")
                                item?.representedObject = value
                            }
                            return button
                        }
                    }
                }
            }
        }
    }
}
