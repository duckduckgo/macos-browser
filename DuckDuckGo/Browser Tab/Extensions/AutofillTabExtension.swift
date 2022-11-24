//
//  Autofill.swift
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

import BrowserServicesKit
import Combine
import Foundation

final class AutofillTabExtension {

    static var emailManagerProvider: (EmailManagerRequestDelegate) -> AutofillEmailDelegate = { delegate in
        let emailManager = EmailManager()
        emailManager.requestDelegate = delegate
        return emailManager
    }

    static var vaultManagerProvider: (SecureVaultManagerDelegate) -> AutofillSecureVaultDelegate = { delegate in
        let manager = SecureVaultManager()
        manager.delegate = delegate
        return manager
    }

    private weak var tab: Tab?
    private var cancellables = Set<AnyCancellable>()

    private weak var autofillScript: WebsiteAutofillUserScript?
    private var emailManager: AutofillEmailDelegate?
    private var vaultManager: AutofillSecureVaultDelegate?

    @Published var autofillDataToSave: AutofillData?

    init(tab: Tab) {
        tab.userScriptsPublisher.sink { [weak self] userScripts in
            guard let self = self,
                  let autofillScript = userScripts?.autofillScript
            else { return }

            self.autofillScript = autofillScript
            autofillScript.currentOverlayTab = self.tab?.delegate
            self.emailManager = Self.emailManagerProvider(self)
            autofillScript.emailDelegate = self.emailManager
            self.vaultManager = Self.vaultManagerProvider(self)
            autofillScript.vaultDelegate = self.vaultManager
        }.store(in: &cancellables)

        tab.clicksPublisher.sink { [weak self] point in
            self?.autofillScript?.clickPoint = point
        }.store(in: &cancellables)
    }

}

extension AutofillTabExtension: SecureVaultManagerDelegate {

    public func secureVaultManagerIsEnabledStatus(_: SecureVaultManager) -> Bool {
        return true
    }

    func secureVaultManager(_: SecureVaultManager, promptUserToStoreAutofillData data: AutofillData) {
        self.autofillDataToSave = data
    }

    func secureVaultManager(_: SecureVaultManager,
                            promptUserToAutofillCredentialsForDomain domain: String,
                            withAccounts accounts: [SecureVaultModels.WebsiteAccount],
                            withTrigger trigger: AutofillUserScript.GetTriggerType,
                            completionHandler: @escaping (SecureVaultModels.WebsiteAccount?) -> Void) {
        // no-op on macOS
    }

    func secureVaultManager(_: SecureVaultManager, didAutofill type: AutofillType, withObjectId objectId: Int64) {
        Pixel.fire(.formAutofilled(kind: type.formAutofillKind))
    }

    func secureVaultManager(_: SecureVaultManager, didRequestAuthenticationWithCompletionHandler handler: @escaping (Bool) -> Void) {
        DeviceAuthenticator.shared.authenticateUser(reason: .autofill) { authenticationResult in
            handler(authenticationResult.authenticated)
        }
    }

    func secureVaultInitFailed(_ error: SecureVaultError) {
        SecureVaultErrorReporter.shared.secureVaultInitFailed(error)
    }

    func secureVaultManagerShouldAutomaticallyUpdateCredentialsWithoutUsername(_: SecureVaultManager) -> Bool {
        return true
    }

}

extension AutofillType {
    var formAutofillKind: Pixel.Event.FormAutofillKind {
        switch self {
        case .password: return .password
        case .card: return .card
        case .identity: return .identity
        }
    }
}

extension AutofillTabExtension: EmailManagerRequestDelegate { }

extension Tab {

    var autofillDataToSavePublisher: AnyPublisher<AutofillData?, Never> {
        extensions.autofill?.$autofillDataToSave.eraseToAnyPublisher() ?? Just(nil).eraseToAnyPublisher()
    }

    func resetAutofillData() {
        extensions.autofill?.autofillDataToSave = nil
    }

}
