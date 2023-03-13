//
//  Preferences.swift
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

enum Preferences {

    enum Const {

        static let pickerHorizontalOffset: CGFloat = {
            if #available(macOS 12.0, *) {
                return -8
            } else {
                return 0
            }
        }()

        enum Fonts {

            static let popUpButton: NSFont = {
                if #available(macOS 11.0, *) {
                    return .preferredFont(forTextStyle: .title1, options: [:])
                } else {
                    return .systemFont(ofSize: 22)
                }
            }()

            static let sideBarItem: Font = {
                if #available(macOS 11.0, *) {
                    return .body
                } else {
                    return .system(size: 13)
                }
            }()

            static let preferencePaneTitle: Font = {
                if #available(macOS 11.0, *) {
                    return .title2.weight(.semibold)
                } else {
                    return .system(size: 17, weight: .semibold)
                }
            }()

            static let preferencePaneSectionHeader: Font = {
                if #available(macOS 11.0, *) {
                    return .title3.weight(.semibold)
                } else {
                    return .system(size: 15, weight: .semibold)
                }
            }()

            static let preferencePaneDisclaimer: Font = {
                if #available(macOS 11.0, *) {
                    return .subheadline
                } else {
                    return .system(size: 10)
                }
            }()
        }
    }

    struct TextMenuTitle: View {
        let text: String

        var body: some View {
            Text(text)
                .font(Const.Fonts.preferencePaneTitle)
        }
    }

    struct TextMenuItemHeader: View {
        let text: String

        var body: some View {
            Text(text)
                .font(Const.Fonts.preferencePaneSectionHeader)
        }
    }

    struct TextMenuItemCaption: View {
        let text: String

        var body: some View {
            Text(text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixMultilineScrollableText()
                .foregroundColor(Color("GreyTextColor"))
        }
    }

    struct TextMenuItemDisclaimer: View {
        let text: String

        var body: some View {
            Text(UserText.autofillPasswordManagerBitwardenDisclaimer)
                .font(Const.Fonts.preferencePaneDisclaimer)
                .foregroundColor(Color("GreyTextColor"))
                .fixMultilineScrollableText()
        }
    }

    struct ToggleMenuItem: View {
        let title: String
        let isOn: Binding<Bool>

        var body: some View {
            Toggle(title, isOn: isOn)
                .fixMultilineScrollableText()
        }
    }
}
