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

import PreferencesUI_macOS
import SwiftUI
import SwiftUIExtensions
import PixelKit

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
        @State private var showingResetNeverPromptSitesSheet = false

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
            PreferencePane(UserText.passwordManagementTitle) {

                if model.showSyncPromo {
                    SyncPromoView(viewModel: model.syncPromoViewModel, layout: .horizontal)
                }

                // Autofill Content  Button
                PreferencePaneSection {
                    Button(UserText.autofillViewContentButtonPasswords) {
                        model.showAutofillPopover(.logins, source: .settings)
                    }
                    Button(UserText.autofillViewContentButtonIdentities) {
                        model.showAutofillPopover(.identities, source: .settings)
                    }
                    Button(UserText.autofillViewContentButtonPaymentMethods) {
                        model.showAutofillPopover(.cards, source: .settings)
                    }
#if APPSTORE
                    Button(UserText.importPasswords) {
                        model.openImportBrowserDataWindow()
                    }
                    Button(UserText.exportLogins) {
                        model.openExportLogins()
                    }
#endif

                }

#if !APPSTORE
                // SECTION 1: Password Manager
                PreferencePaneSection(UserText.autofillPasswordManager) {
                    VStack(alignment: .leading, spacing: 6) {
                        passwordManagerPicker(passwordManagerBinding) {
                            Text(UserText.autofillPasswordManagerDuckDuckGo).tag(PasswordManager.duckduckgo)
                        }
                    }

                    if model.passwordManager != .bitwarden {
                        VStack {
                            Button(UserText.importPasswords) {
                                model.openImportBrowserDataWindow()
                            }
                            Button(UserText.exportLogins) {
                                model.openExportLogins()
                            }
                        }
                        .padding(.leading, 15)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        passwordManagerPicker(passwordManagerBinding) {
                            Text(UserText.autofillPasswordManagerBitwarden).tag(PasswordManager.bitwarden)
                        }
                        if model.passwordManager == .bitwarden && !model.isBitwardenSetupFlowPresented {
                            bitwardenStatusView(for: bitwardenManager.status)
                        }
                    }
                }
#endif

                // SECTION 2: Ask to Save:
                PreferencePaneSection {
                    TextMenuItemHeader(UserText.autofillAskToSave)
                    VStack(alignment: .leading, spacing: 6) {
                        ToggleMenuItem(UserText.autofillPasswords, isOn: $model.askToSaveUsernamesAndPasswords)
                        ToggleMenuItem(UserText.autofillAddresses, isOn: $model.askToSaveAddresses)
                        ToggleMenuItem(UserText.autofillPaymentMethods, isOn: $model.askToSavePaymentMethods)
                    }
                    TextMenuItemCaption(UserText.autofillAskToSaveExplanation)
                }

                // SECTION 3: Reset excluded (aka never prompt to save) sites:
                // This is only displayed if the user has never prompt sites saved & not using Bitwarden
                if model.hasNeverPromptWebsites && model.passwordManager == .duckduckgo {
                    PreferencePaneSection {
                        TextMenuItemHeader(UserText.autofillExcludedSites)
                        TextMenuItemCaption(UserText.autofillExcludedSitesExplanation)
                            .padding(.top, -8)
                        Button(UserText.autofillExcludedSitesReset) {
                            showingResetNeverPromptSitesSheet.toggle()
                            if showingResetNeverPromptSitesSheet {
                                PixelKit.fire(GeneralPixel.autofillLoginsSettingsResetExcludedDisplayed)
                            }
                        }
                    }.sheet(isPresented: $showingResetNeverPromptSitesSheet) {
                        ResetNeverPromptSitesSheet(autofillPreferencesModel: model, isSheetPresented: $showingResetNeverPromptSitesSheet)
                    }
                }

                // SECTION 4: Auto-Lock:

                PreferencePaneSection {
                    TextMenuItemHeader(UserText.autofillAutoLock)
                    Picker(selection: isAutoLockEnabledBinding, content: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(UserText.autofillLockWhenIdle)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .multilineTextAlignment(.leading)
                                NSPopUpButtonView(selection: autoLockThresholdBinding) {
                                    let button = NSPopUpButton()
                                    button.setContentHuggingPriority(.defaultHigh, for: .horizontal)

                                    for threshold in AutofillAutoLockThreshold.allCases {
                                        let item = button.menu?.addItem(withTitle: threshold.title, action: nil, keyEquivalent: "")
                                        item?.representedObject = threshold
                                    }
                                    return button
                                }.disabled(!model.isAutoLockEnabled)
                            }
                            // We have to use a custom toggle here, as with a SwiftUI Toggle on macOS 10.x to 13.x, the checkbox gets rendered
                            // to the right when inside a picker 🤷
                            NativeCheckboxToggle(isOn: $model.autolockLocksFormFilling, label: UserText.autolockLocksFormFill)
                                .disabled(!model.isAutoLockEnabled)
                                .padding(.bottom, 6)
                        }.tag(true)
                        Text(UserText.autofillNeverLock).tag(false)
                    }, label: {})
                    .pickerStyle(.radioGroup)
                    .offset(x: PreferencesUI_macOS.Const.pickerHorizontalOffset)
                    TextMenuItemCaption(UserText.autofillNeverLockWarning)
                }
            }
        }

        @ViewBuilder
        private func passwordManagerPicker(_ binding: Binding<PasswordManager>, @ViewBuilder content: @escaping () -> some View) -> some View {
            Picker(selection: binding, content: {
                content()
            }, label: {})
            .pickerStyle(.radioGroup)
            .offset(x: PreferencesUI_macOS.Const.pickerHorizontalOffset)
        }

        @ViewBuilder private func bitwardenStatusView(for status: BWStatus) -> some View {
            switch status {
            case .disabled:
                BitwardenStatusView(iconType: .error,
                                    title: UserText.bitwardenPreferencesUnableToConnect,
                                    buttonValue: .init(title: UserText.bitwardenPreferencesCompleteSetup, action: { model.presentBitwardenSetupFlow() }))
                .offset(x: Preferences.Const.autoLockWarningOffset)
            case .notInstalled:
                BitwardenStatusView(iconType: .warning,
                                    title: UserText.bitwardenNotInstalled)
                .offset(x: Preferences.Const.autoLockWarningOffset)
            case .oldVersion:
                BitwardenStatusView(iconType: .warning,
                                    title: UserText.bitwardenOldVersion)
                .offset(x: Preferences.Const.autoLockWarningOffset)
            case .incompatible:
                BitwardenStatusView(iconType: .warning,
                                    title: UserText.bitwardenIncompatible,
                                    content: AnyView(BitwardenDowngradeInfoView()))
                .offset(x: Preferences.Const.autoLockWarningOffset)
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
            case .accessToContainersNotApproved:
                BitwardenStatusView(iconType: .error,
                                    title: UserText.bitwardenCantAccessContainer,
                                    buttonValue: .init(title: UserText.openSystemSettings, action: { model.openSettings() }))
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
    }
}

private struct BitwardenStatusView: View {

    internal init(iconType: BitwardenStatusView.IconType, title: String, buttonValue: BitwardenStatusView.ButtonValue? = nil, content: AnyView? = nil) {
        self.iconType = iconType
        self.title = title
        self.buttonValue = buttonValue
        self.content = content
    }

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
    let content: AnyView?

    var body: some View {

        VStack(alignment: .leading) {
            HStack(alignment: .top) {
                Image(iconType.imageName)
                    .padding(.top, 2)
                VStack(alignment: .leading) {
                    Text(title)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding([.top, .bottom], 2)
                    if let content {
                        content.padding([.top, .bottom], 2)
                    }
                }
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

struct BitwardenDowngradeInfoView: View, PreferencesTabOpening {

    var body: some View {
        VStack(alignment: .leading) {
            VStack(alignment: .leading) {
                HStack {
                    Text("1.")
                    Button(UserText.bitwardenIncompatibleStep1, action: {
                        openNewTab(with: URL(string: "https://github.com/bitwarden/clients/releases/download/desktop-v2024.9.0/Bitwarden-2024.9.0-universal.dmg")!)
                    }).foregroundColor(.accentColor)
                }
                Text(UserText.bitwardenIncompatibleStep2)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct ResetNeverPromptSitesSheet: View {

    @ObservedObject var autofillPreferencesModel: AutofillPreferencesModel
    @Binding var isSheetPresented: Bool

    var body: some View {
        VStack(alignment: .center) {
            TextMenuTitle(UserText.autofillExcludedSitesResetActionTitle)
                .padding(.top, 10)

            Text(UserText.autofillExcludedSitesResetActionMessage)
                .padding(.vertical, 10)
                .padding(.horizontal, 20)
                .frame(width: 300)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            HStack(alignment: .center) {
                Spacer()
                Button(UserText.cancel) {
                    isSheetPresented.toggle()
                    PixelKit.fire(GeneralPixel.autofillLoginsSettingsResetExcludedDismissed)
                }
                Button(action: {
                    saveChanges()
                }, label: {
                    Text(UserText.autofillExcludedSitesReset)
                        .foregroundColor(.red)
                })
            }.padding(EdgeInsets(top: 10, leading: 0, bottom: 10, trailing: 15))

        }
        .padding(.vertical, 10)
    }

    private func saveChanges() {
        autofillPreferencesModel.resetNeverPromptWebsites()
        isSheetPresented.toggle()
        PixelKit.fire(GeneralPixel.autofillLoginsSettingsResetExcludedConfirmed)
    }

}
