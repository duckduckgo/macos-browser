//
//  PreferencesAutofillView.swift
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

    static let autoLockWarningOffset: CGFloat = {
        return 20
    }()

}

extension Preferences {

    struct AutofillView: View {
        @ObservedObject var model: AutofillPreferencesModel

        var isAutoLockEnabledBinding: Binding<Bool> {
            .init {
                model.isAutoLockEnabled
            } set: { newValue in
                model.authorizeAutoLockSettingsChange(isEnabled: newValue)
            }
        }

        var autoLockThresholdBinding: Binding<AutofillAutoLockThreshold> {
            .init {
                model.autoLockThreshold
            } set: { newValue in
                model.authorizeAutoLockSettingsChange(threshold: newValue)
            }
        }

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
                        Toggle(UserText.autofillAddresses, isOn: $model.askToSaveAddresses)
                        Toggle(UserText.autofillPaymentMethods, isOn: $model.askToSavePaymentMethods)
                    }
                }

                Section(spacing: 0) {
                    Text(UserText.autofillAutoLock)
                        .font(Const.Fonts.preferencePaneSectionHeader)
                        .padding(.bottom, 12)

                    VStack(alignment: .leading) {
                        let group = RadioButtonGroup(selection: model.isAutoLockEnabled ? 0 : 1) { selection in
                            // Lock app until authenticated
                            var condition: RunLoop.ResumeCondition?
                            if selection == 1 {
                                condition = RunLoop.ResumeCondition()
                            }
                            model.authorizeAutoLockSettingsChange(isEnabled: selection == 0) { _ in
                                if let condition = condition {
                                    condition.resolve()
                                }
                            }
                            if let condition = condition {
                                RunLoop.main.run(until: condition)
                            }
                        }
                        HStack {
                            RadioButton(title: UserText.autofillLockWhenIdle, group: group)
                            NSPopUpButtonView(selection: autoLockThresholdBinding) {
                                let button = NSPopUpButton()
                                button.setContentHuggingPriority(.defaultHigh, for: .horizontal)

                                for threshold in AutofillAutoLockThreshold.allCases {
                                    let item = button.menu?.addItem(withTitle: threshold.title, action: nil, keyEquivalent: "")
                                    item?.representedObject = threshold
                                }
                                return button
                            }
                            .disabled(!model.isAutoLockEnabled)
                        }
                        RadioButton(title: UserText.autofillNeverLock, group: group)
                    }
                    .padding(.bottom, 6)

                    Text(UserText.autofillNeverLockWarning)
                        .font(Const.Fonts.preferencePaneCaption)
                        .foregroundColor(Color("GreyTextColor"))
                        .fixMultilineScrollableText()
                        .offset(x: Const.autoLockWarningOffset)
                }

                Section(spacing: 0) {
                    Button(UserText.importBrowserData) {
                        model.openImportBrowserDataWindow()
                    }
                }
            }
        }
    }
}
