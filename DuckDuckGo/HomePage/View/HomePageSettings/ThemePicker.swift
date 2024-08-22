//
//  ThemePicker.swift
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

import SwiftUIExtensions

extension HomePage.Views {

    struct ThemePicker: View {
        @EnvironmentObject var appearancePreferences: AppearancePreferences

        var body: some View {
            HStack(spacing: 24) {
                ForEach(ThemeName.allCases, id: \.self) { theme in
                    themeButton(for: theme)
                }
            }
        }

        func themeButton(for themeName: ThemeName) -> some View {
            Button {
                appearancePreferences.currentThemeName = themeName
            } label: {
                VStack(spacing: 6) {
                    ZStack {
                        themeName.pickerView
                        Circle()
                            .stroke(Color.black.opacity(0.12))
                    }
                    .frame(width: 42, height: 42)
                    .padding(2)
                    .background(selectionBackground(for: themeName))

                    Text(themeName.displayName)
                }
            }
            .buttonStyle(.plain)
        }

        func selectionBackground(for themeName: ThemeName) -> some View {
            Group {
                if appearancePreferences.currentThemeName == themeName {
                    Circle()
                        .stroke(Color(.linkBlue), lineWidth: 2)
                } else {
                    EmptyView()
                }
            }
        }
    }
}

fileprivate extension ThemeName {
    @ViewBuilder
    var pickerView: some View {
        switch self {
        case .light:
            Circle().fill(Color.colorSchemePickerWhite)
        case .dark:
            Circle().fill(Color.colorSchemePickerBlack)
        case .systemDefault:
            GeometryReader { geometry in
                ZStack {
                    Circle()
                        .fill(Color.colorSchemePickerWhite)
                        .clipShape(Rectangle().offset(x: -geometry.size.width/2))
                    Circle()
                        .fill(Color.colorSchemePickerBlack)
                        .clipShape(Rectangle().offset(x: geometry.size.width/2))
                }
            }
        }
    }
}
