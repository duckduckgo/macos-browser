//
//  AutofillPreferencesModel.swift
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

import Foundation

final class AutofillPreferencesModel: ObservableObject {

    @Published var askToSaveUsernamesAndPasswords: Bool {
        didSet {
            persistor.askToSaveUsernamesAndPasswords = askToSaveUsernamesAndPasswords
        }
    }

    @Published var askToSaveAddresses: Bool {
        didSet {
            persistor.askToSaveAddresses = askToSaveAddresses
        }
    }

    @Published var askToSavePaymentMethods: Bool {
        didSet {
            persistor.askToSavePaymentMethods = askToSavePaymentMethods
        }
    }

    @Published private(set) var isAutoLockEnabled: Bool {
        didSet {
            persistor.isAutoLockEnabled = isAutoLockEnabled
        }
    }

    @Published private(set) var autoLockThreshold: AutofillAutoLockThreshold {
        didSet {
            persistor.autoLockThreshold = autoLockThreshold
        }
    }
    
    @Published private(set) var passwordManager: PasswordManager {
        didSet {
            persistor.passwordManager = passwordManager

            let enabled = passwordManager == .bitwarden
            PasswordManagerCoordinator.shared.setEnabled(enabled)
            if enabled {
                presentBitwardenSetupFlow()
            }
        }
    }

    @Published private(set) var isBitwardenSetupFlowPresented = false

    func authorizeAutoLockSettingsChange(
        isEnabled isAutoLockEnabledNewValue: Bool? = nil,
        threshold autoLockThresholdNewValue: AutofillAutoLockThreshold? = nil
    ) {
        guard isAutoLockEnabledNewValue != nil || autoLockThresholdNewValue != nil else {
            return
        }

        let isAutoLockEnabled = isAutoLockEnabledNewValue ?? self.isAutoLockEnabled
        let autoLockThreshold = autoLockThresholdNewValue ?? self.autoLockThreshold

        userAuthenticator.authenticateUser(reason: .changeLoginsSettings) { [weak self] authenticationResult in
            guard let self = self else {
                return
            }

            if authenticationResult.authenticated {
                if isAutoLockEnabled != self.isAutoLockEnabled {
                    self.isAutoLockEnabled = isAutoLockEnabled
                }

                if autoLockThreshold != self.autoLockThreshold {
                    self.autoLockThreshold = autoLockThreshold
                }
            }
        }
    }
    
    func passwordManagerSettingsChange(passwordManager: PasswordManager) {
        self.passwordManager = passwordManager
    }

    func openImportBrowserDataWindow() {
        NSApp.sendAction(#selector(AppDelegate.openImportBrowserDataWindow(_:)), to: nil, from: nil)
    }

    init(
        persistor: AutofillPreferencesPersistor = AutofillPreferences(),
        userAuthenticator: UserAuthenticating = DeviceAuthenticator.shared,
        bitwardenInstallationService: BWInstallationService = LocalBitwardenInstallationService()
    ) {
        self.persistor = persistor
        self.userAuthenticator = userAuthenticator
        self.bitwardenInstallationService = bitwardenInstallationService

        isAutoLockEnabled = persistor.isAutoLockEnabled
        autoLockThreshold = persistor.autoLockThreshold
        askToSaveUsernamesAndPasswords = persistor.askToSaveUsernamesAndPasswords
        askToSaveAddresses = persistor.askToSaveAddresses
        askToSavePaymentMethods = persistor.askToSavePaymentMethods
        passwordManager = persistor.passwordManager
    }

    private var persistor: AutofillPreferencesPersistor
    private var userAuthenticator: UserAuthenticating
    private let bitwardenInstallationService: BWInstallationService
    
    // MARK: - Password Manager
    
    func presentBitwardenSetupFlow() {
        let connectBitwardenViewController = ConnectBitwardenViewController(nibName: nil, bundle: nil)
        let connectBitwardenWindowController = connectBitwardenViewController.wrappedInWindowController()
        
        connectBitwardenViewController.setupFlowCancellationHandler = { [weak self] in
            self?.passwordManager = .duckduckgo
        }

        guard let connectBitwardenWindow = connectBitwardenWindowController.window,
              let parentWindowController = WindowControllersManager.shared.lastKeyMainWindowController
        else {
            assertionFailure("Privacy Preferences: Failed to present ConnectBitwardenViewController")
            return
        }

        isBitwardenSetupFlowPresented = true
        parentWindowController.window?.beginSheet(connectBitwardenWindow) { [weak self] _ in
            self?.isBitwardenSetupFlowPresented = false
        }
    }
    
    func openBitwarden() {
        PasswordManagerCoordinator.shared.openPasswordManager()
    }

}
