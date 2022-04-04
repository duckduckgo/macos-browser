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

                // Only fire the auto-lock disabled pixel the setting is disabled and it has changed from its previous value
                if !isAutoLockEnabled && self.isAutoLockEnabled {
                    Pixel.fire(.passwordManagerLockScreenDisabled)
                }

                // Only fire the threshold pixel if it has changed, or if the setting is being turned on again
                if (autoLockThreshold != self.autoLockThreshold) || (isAutoLockEnabled && !self.isAutoLockEnabled) {
                    Pixel.fire(self.autoLockThreshold.pixelEvent)
                }

                if isAutoLockEnabled != self.isAutoLockEnabled {
                    self.isAutoLockEnabled = isAutoLockEnabled
                }
                if autoLockThreshold != self.autoLockThreshold {
                    self.autoLockThreshold = autoLockThreshold
                }
            }
        }
    }

    func openImportBrowserDataWindow() {
        NSApp.sendAction(#selector(AppDelegate.openImportBrowserDataWindow(_:)), to: nil, from: nil)
    }

    init(
        persistor: AutofillPreferencesPersistor = AutofillPreferences(),
        userAuthenticator: UserAuthenticating = DeviceAuthenticator.shared
    ) {
        self.persistor = persistor
        self.userAuthenticator = userAuthenticator

        isAutoLockEnabled = persistor.isAutoLockEnabled
        autoLockThreshold = persistor.autoLockThreshold
        askToSaveUsernamesAndPasswords = persistor.askToSaveUsernamesAndPasswords
        askToSaveAddresses = persistor.askToSaveAddresses
        askToSavePaymentMethods = persistor.askToSavePaymentMethods
    }

    private var persistor: AutofillPreferencesPersistor
    private var userAuthenticator: UserAuthenticating
}
