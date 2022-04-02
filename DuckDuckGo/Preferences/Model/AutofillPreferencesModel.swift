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

    @Published var isAutoLockEnabled: Bool {
        didSet {
            persistor.isAutoLockEnabled = isAutoLockEnabled
        }
    }

    @Published var autoLockThreshold: AutofillAutoLockThreshold {
        didSet {
            persistor.autoLockThreshold = autoLockThreshold
        }
    }

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

    init(persistor: AutofillPreferencesPersistor = AutofillPreferences()) {
        self.persistor = persistor

        isAutoLockEnabled = persistor.isAutoLockEnabled
        autoLockThreshold = persistor.autoLockThreshold
        askToSaveUsernamesAndPasswords = persistor.askToSaveUsernamesAndPasswords
        askToSaveAddresses = persistor.askToSaveAddresses
        askToSavePaymentMethods = persistor.askToSavePaymentMethods
    }

    private var persistor: AutofillPreferencesPersistor
}
