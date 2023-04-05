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
import SwiftUIExtensions

fileprivate extension Preferences.Const {
    static let autoLockWarningOffset: CGFloat = {
        if #available(macOS 12.0, *) {
            return 18
        } else {
            return 20
        }
    }()
}

extension Preferences {

    struct AutofillView: View {
        @ObservedObject var model: AutofillPreferencesModel
        @ObservedObject var bitwardenManager = BWManager.shared

        var passwordManagerBinding: Binding<PasswordManager> {
            .init {
                model.passwordManager
            } set: { newValue in
                model.passwordManagerSettingsChange(passwordManager: newValue)
            }
        }

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

                // Autofill Content  Button
                PreferencePaneSection {
                    Button(UserText.autofillViewContentButton) {
                        model.showAutofillPopover()
                    }
                }

#if !APPSTORE
                // Password Manager:
                PreferencePaneSection(spacing: 0) {
                    Text(UserText.autofillPasswordManager)
                        .font(Const.Fonts.preferencePaneSectionHeader)
                        .padding(.bottom, 6)

                    Picker(selection: passwordManagerBinding, content: {
                        Text(UserText.autofillPasswordManagerDuckDuckGo).tag(PasswordManager.duckduckgo)

                        Text(UserText.autofillPasswordManagerBitwarden).tag(PasswordManager.bitwarden)
                    }, label: {})
                    .pickerStyle(.radioGroup)
                    .offset(x: Const.pickerHorizontalOffset)
                    .padding(.bottom, 6)

                    switch (model.passwordManager, model.isBitwardenSetupFlowPresented) {
                    case (.bitwarden, false):
                        bitwardenStatusView(for: bitwardenManager.status)
                    case (.duckduckgo, _), (.bitwarden, true):
                        Text(UserText.autofillPasswordManagerBitwardenDisclaimer)
                            .font(Const.Fonts.preferencePaneCaption)
                            .foregroundColor(Color("GreyTextColor"))
                            .fixMultilineScrollableText()
                            .offset(x: Const.autoLockWarningOffset)
                    }
                }
#endif

                // Ask to Save:

                PreferencePaneSection(spacing: 0) {
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

                // Auto-Lock:

                PreferencePaneSection(spacing: 0) {
                    Text(UserText.autofillAutoLock)
                        .font(Const.Fonts.preferencePaneSectionHeader)
                        .padding(.bottom, 12)

                    Picker(selection: isAutoLockEnabledBinding, content: {
                        HStack {
                            Text(UserText.autofillLockWhenIdle)
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
                        }.tag(true)
                        Text(UserText.autofillNeverLock).tag(false)
                    }, label: {})
                    .pickerStyle(.radioGroup)
                    .offset(x: Const.pickerHorizontalOffset)
                    .padding(.bottom, 6)

                    Text(UserText.autofillNeverLockWarning)
                        .font(Const.Fonts.preferencePaneCaption)
                        .foregroundColor(Color("GreyTextColor"))
                        .fixMultilineScrollableText()
                        .offset(x: Const.autoLockWarningOffset)
                }

                PreferencePaneSection(spacing: 0) {
                    Button(UserText.importBrowserData) {
                        model.openImportBrowserDataWindow()
                    }
                }
            }
        }

        // swiftlint:disable cyclomatic_complexity
        // swiftlint:disable function_body_length
        @ViewBuilder private func bitwardenStatusView(for status: BWStatus) -> some View {
            switch status {
            case .disabled:
                BitwardenStatusView(iconType: .error,
                                    title: UserText.bitwardenPreferencesUnableToConnect,
                                    buttonValue: .init(title: UserText.bitwardenPreferencesCompleteSetup, action: { model.presentBitwardenSetupFlow() }))
                .offset(x: Preferences.Const.autoLockWarningOffset)
            case .notInstalled:
                BitwardenStatusView(iconType: .warning,
                                    title: UserText.bitwardenNotInstalled,
                                    buttonValue: nil)
                .offset(x: Preferences.Const.autoLockWarningOffset)
            case .oldVersion:
                BitwardenStatusView(iconType: .warning,
                                    title: UserText.bitwardenOldVersion,
                                    buttonValue: nil)
                .offset(x: Preferences.Const.autoLockWarningOffset)
            case .notRunning:
                BitwardenStatusView(iconType: .warning,
                                    title: UserText.bitwardenPreferencesRun,
                                    buttonValue: .init(title: UserText.bitwardenPreferencesOpenBitwarden, action: { model.openBitwarden() }))
                .offset(x: Preferences.Const.autoLockWarningOffset)
            case .integrationNotApproved:
                BitwardenStatusView(iconType: .error,
                                    title: UserText.bitwardenIntegrationNotApproved,
                                    buttonValue: .init(title: UserText.bitwardenPreferencesCompleteSetup, action: { model.presentBitwardenSetupFlow() }))
                .offset(x: Preferences.Const.autoLockWarningOffset)
            case .missingHandshake:
                BitwardenStatusView(iconType: .error,
                                    title: UserText.bitwardenMissingHandshake,
                                    buttonValue: .init(title: UserText.bitwardenPreferencesCompleteSetup, action: { model.presentBitwardenSetupFlow() }))
                .offset(x: Preferences.Const.autoLockWarningOffset)
            case .waitingForHandshakeApproval:
                BitwardenStatusView(iconType: .error,
                                    title: UserText.bitwardenWaitingForHandshake,
                                    buttonValue: .init(title: UserText.bitwardenPreferencesCompleteSetup, action: { model.presentBitwardenSetupFlow() }))
                .offset(x: Preferences.Const.autoLockWarningOffset)
            case .handshakeNotApproved:
                BitwardenStatusView(iconType: .error,
                                    title: UserText.bitwardenHanshakeNotApproved,
                                    buttonValue: .init(title: UserText.bitwardenPreferencesCompleteSetup, action: { model.presentBitwardenSetupFlow() }))
                .offset(x: Preferences.Const.autoLockWarningOffset)
            case .connecting:
                BitwardenStatusView(iconType: .warning,
                                    title: UserText.bitwardenConnecting,
                                    buttonValue: .init(title: UserText.bitwardenPreferencesOpenBitwarden, action: { model.openBitwarden() }))
                .offset(x: Preferences.Const.autoLockWarningOffset)
            case .waitingForStatusResponse:
                BitwardenStatusView(iconType: .warning,
                                    title: UserText.bitwardenWaitingForStatusResponse,
                                    buttonValue: .init(title: UserText.bitwardenPreferencesOpenBitwarden, action: { model.openBitwarden() }))
                .offset(x: Preferences.Const.autoLockWarningOffset)

            case .connected(vault: let vault):
                switch vault.status {
                case .locked:
                    BitwardenStatusView(iconType: .warning,
                                        title: UserText.bitwardenPreferencesUnlock,
                                        buttonValue: .init(title: UserText.bitwardenPreferencesOpenBitwarden, action: { model.openBitwarden() }))
                    .offset(x: Preferences.Const.autoLockWarningOffset)
                case .unlocked:
                    BitwardenStatusView(iconType: .success,
                                        title: vault.email,
                                        buttonValue: .init(title: UserText.bitwardenPreferencesOpenBitwarden, action: { model.openBitwarden() }))
                    .offset(x: Preferences.Const.autoLockWarningOffset)
                }
            case .error:
                BitwardenStatusView(iconType: .error,
                                    title: UserText.bitwardenError,
                                    buttonValue: nil)
                .offset(x: Preferences.Const.autoLockWarningOffset)
            }
        }
        // swiftlint:enable cyclomatic_complexity
        // swiftlint:enable function_body_length
    }
}

private struct BitwardenStatusView: View {

    struct ButtonValue {
        let title: String
        let action: () -> Void
    }

    enum IconType {
        case success
        case warning
        case error

        fileprivate var imageName: String {
            switch self {
            case .success: return "SuccessCheckmark"
            case .warning: return "Warning"
            case .error: return "Error"
            }
        }
    }

    let iconType: IconType
    let title: String
    let buttonValue: ButtonValue?

    var body: some View {

        HStack {
            HStack {
                Image(iconType.imageName)
                Text(title)
            }
            .padding([.leading, .trailing], 6)
            .padding([.top, .bottom], 2)
            .background(Color.black.opacity(0.04))
            .cornerRadius(5)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )

            if let buttonValue = buttonValue {
                Button(buttonValue.title, action: buttonValue.action)
            }
        }

    }

}
