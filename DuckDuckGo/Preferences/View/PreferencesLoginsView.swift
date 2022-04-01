//
//  PreferencesLoginsView.swift
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

fileprivate extension Preferences.Const {
    static let autoLockPickerHorizontalOffset: CGFloat = {
        if #available(macOS 12.0, *) {
            return -8
        } else {
            return 0
        }
    }()

    static let autoLockWarningOffset: CGFloat = {
        if #available(macOS 12.0, *) {
            return 18
        } else {
            return 20
        }
    }()

}

extension Preferences {

    struct LoginsView: View {
        @ObservedObject var model: LoginsPreferences

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                Text(UserText.autofill)
                    .font(Const.Fonts.preferencePaneTitle)

                Section(spacing: 0) {
                    Text(UserText.autofillAskToSave)
                        .font(Const.Fonts.preferencePaneSectionHeader)
                        .padding(.bottom, 6)

                    Text(UserText.autofillAskToSaveExplanation)
                        .font(Const.Fonts.preferencePaneCaption)
                        .foregroundColor(Color("GreyTextColor"))
                        .fixMultilineScrollableText()
                        .padding(.bottom, 12)

                    VStack(alignment: .leading, spacing: 6) {
                        Toggle(UserText.autofillUsernamesAndPasswords, isOn: $model.askToSaveUsernamesAndPasswords)
                            .fixMultilineScrollableText()
                        Toggle(UserText.autofillAddresses, isOn: $model.askToSaveAddresses)
                            .fixMultilineScrollableText()
                        Toggle(UserText.autofillPaymentMethods, isOn: $model.askToSavePaymentMethods)
                            .fixMultilineScrollableText()
                    }
                }

                Section(spacing: 0) {
                    Text(UserText.autofillAutoLock)
                        .font(Const.Fonts.preferencePaneSectionHeader)
                        .padding(.bottom, 12)

                    Picker(selection: $model.shouldAutoLockLogins, content: {
                        HStack {
                            Text(UserText.autofillLockWhenIdle)
                            NSPopUpButtonView(selection: $model.autoLockThreshold) {
                                let button = NSPopUpButton()
                                button.setContentHuggingPriority(.defaultHigh, for: .horizontal)

                                for threshold in LoginsPreferences.AutoLockThreshold.allCases {
                                    let item = button.menu?.addItem(withTitle: threshold.title, action: nil, keyEquivalent: "")
                                    item?.representedObject = threshold
                                }
                                return button
                            }
                            .disabled(!model.shouldAutoLockLogins)
                        }.tag(true)
                        Text(UserText.autofillNeverLock).tag(false)
                    }, label: {})
                    .pickerStyle(.radioGroup)
                    .offset(x: Const.autoLockPickerHorizontalOffset)
                    .padding(.bottom, 6)

                    Text(UserText.autofillNeverLockWarning)
                        .font(Const.Fonts.preferencePaneCaption)
                        .foregroundColor(Color("GreyTextColor"))
                        .fixMultilineScrollableText()
                        .offset(x: Const.autoLockWarningOffset)
                }

                Section(spacing: 0) {
                    Button(UserText.importBrowserData) {
                        NSApp.sendAction(#selector(AppDelegate.openImportBrowserDataWindow(_:)), to: nil, from: nil)
                    }
                }
            }
        }
    }
}
