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
import BrowserServicesKit
import PixelKit

final class AutofillPreferencesModel: ObservableObject {

    @Published var askToSaveUsernamesAndPasswords: Bool {
        didSet {
            persistor.askToSaveUsernamesAndPasswords = askToSaveUsernamesAndPasswords
            NotificationCenter.default.post(name: .autofillUserSettingsDidChange, object: nil)
            PixelKit.fire(askToSaveUsernamesAndPasswords ? GeneralPixel.autofillLoginsSettingsEnabled : GeneralPixel.autofillLoginsSettingsDisabled)
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
            NotificationCenter.default.post(name: .autofillUserSettingsDidChange, object: nil)
        }
    }

    @Published private(set) var isAutoLockEnabled: Bool {
        didSet {
            persistor.isAutoLockEnabled = isAutoLockEnabled
        }
    }

    var previousAutoLockThreshold: AutofillAutoLockThreshold
    @Published private(set) var autoLockThreshold: AutofillAutoLockThreshold {
        didSet {
            persistor.autoLockThreshold = autoLockThreshold
        }
    }

    @Published var autolockLocksFormFilling: Bool {
        didSet {
            persistor.autolockLocksFormFilling = autolockLocksFormFilling
        }
    }

    @MainActor
    @Published private(set) var passwordManager: PasswordManager {
        didSet {
            persistor.passwordManager = passwordManager

            let enabled = passwordManager == .bitwarden
            PasswordManagerCoordinator.shared.setEnabled(enabled)
            if enabled {
                presentBitwardenSetupFlow()
                showSyncPromo = false
            } else {
                setShouldShowSyncPromo()
            }
        }
    }

    @Published private(set) var isBitwardenSetupFlowPresented = false

    @Published private(set) var hasNeverPromptWebsites: Bool = false

    @Published private(set) var showSyncPromo: Bool = false

    func authorizeAutoLockSettingsChange(
        isEnabled isAutoLockEnabledNewValue: Bool? = nil,
        threshold autoLockThresholdNewValue: AutofillAutoLockThreshold? = nil
    ) {
        guard isAutoLockEnabledNewValue != nil || autoLockThresholdNewValue != nil else {
            return
        }

        previousAutoLockThreshold = self.autoLockThreshold
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
                } else {
                    self.autoLockThreshold = previousAutoLockThreshold
                }
            }
        }
    }

    @MainActor
    func passwordManagerSettingsChange(passwordManager: PasswordManager) {
        self.passwordManager = passwordManager
    }

    func openImportBrowserDataWindow() {
        NSApp.sendAction(#selector(AppDelegate.openImportBrowserDataWindow(_:)), to: nil, from: nil)
    }

    func openExportLogins() {
        NSApp.sendAction(#selector(AppDelegate.openExportLogins(_:)), to: nil, from: nil)
    }

    @MainActor
    func showAutofillPopover(_ selectedCategory: SecureVaultSorting.Category = .allItems, source: PasswordManagementSource) {
        guard let parentWindowController = WindowControllersManager.shared.lastKeyMainWindowController else { return }
        let navigationViewController = parentWindowController.mainViewController.navigationBarViewController
        navigationViewController.showPasswordManagerPopover(selectedCategory: selectedCategory, source: source)
    }

    func resetNeverPromptWebsites() {
        _ = neverPromptWebsitesManager.deleteAllNeverPromptWebsites()
        hasNeverPromptWebsites = !neverPromptWebsitesManager.neverPromptWebsites.isEmpty
    }

    @MainActor
    init(
        persistor: AutofillPreferencesPersistor = AutofillPreferences(),
        userAuthenticator: UserAuthenticating = DeviceAuthenticator.shared,
        bitwardenInstallationService: BWInstallationService = LocalBitwardenInstallationService(),
        neverPromptWebsitesManager: AutofillNeverPromptWebsitesManager = AutofillNeverPromptWebsitesManager.shared
    ) {
        self.persistor = persistor
        self.userAuthenticator = userAuthenticator
        self.bitwardenInstallationService = bitwardenInstallationService
        self.neverPromptWebsitesManager = neverPromptWebsitesManager

        isAutoLockEnabled = persistor.isAutoLockEnabled
        autoLockThreshold = persistor.autoLockThreshold
        previousAutoLockThreshold = persistor.autoLockThreshold
        askToSaveUsernamesAndPasswords = persistor.askToSaveUsernamesAndPasswords
        askToSaveAddresses = persistor.askToSaveAddresses
        askToSavePaymentMethods = persistor.askToSavePaymentMethods
        autolockLocksFormFilling = persistor.autolockLocksFormFilling
        passwordManager = persistor.passwordManager
        hasNeverPromptWebsites = !neverPromptWebsitesManager.neverPromptWebsites.isEmpty
        setShouldShowSyncPromo()
    }

    private var persistor: AutofillPreferencesPersistor
    private var userAuthenticator: UserAuthenticating
    private let bitwardenInstallationService: BWInstallationService
    private let neverPromptWebsitesManager: AutofillNeverPromptWebsitesManager
    private lazy var syncPromoManager: SyncPromoManaging = SyncPromoManager()
    lazy var syncPromoViewModel: SyncPromoViewModel = SyncPromoViewModel(touchpointType: .passwords,
                                                                         primaryButtonAction: { [weak self] in
        self?.syncPromoManager.goToSyncSettings(for: .passwords)
    },
                                                                         dismissButtonAction: { [weak self] in
        self?.syncPromoManager.dismissPromoFor(.passwords)
        self?.showSyncPromo = false
    })

    // MARK: - Password Manager

    @MainActor
    func presentBitwardenSetupFlow() {
        let connectBitwardenViewController = ConnectBitwardenViewController(nibName: nil, bundle: nil)
        let connectBitwardenWindowController = connectBitwardenViewController.wrappedInWindowController()

        connectBitwardenViewController.setupFlowCancellationHandler = { [weak self] in
            self?.passwordManager = .duckduckgo
            self?.setShouldShowSyncPromo()
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

    func openSettings() {
        NSWorkspace.shared.open(.fullDiskAccess)
    }

    private func setShouldShowSyncPromo() {
        guard syncPromoManager.shouldPresentPromoFor(.passwords),
                let vault = try? AutofillSecureVaultFactory.makeVault(reporter: SecureVaultReporter.shared),
                let accountsCount = try? vault.accountsCount() else {
            showSyncPromo = false
            return
        }

        showSyncPromo = accountsCount > 0
    }
}
