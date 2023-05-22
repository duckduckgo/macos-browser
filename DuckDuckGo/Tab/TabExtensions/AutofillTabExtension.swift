//
//  AutofillTabExtension.swift
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

final class AutofillTabExtension: TabExtension {

    static var emailManagerProvider: (EmailManagerRequestDelegate) -> AutofillEmailDelegate = { delegate in
        let emailManager = EmailManager()
        emailManager.requestDelegate = delegate
        return emailManager
    }

    static var vaultManagerProvider: (SecureVaultManagerDelegate) -> AutofillSecureVaultDelegate = { delegate in
        let manager = SecureVaultManager(passwordManager: PasswordManagerCoordinator.shared,
                                         includePartialAccountMatches: true,
                                         tld: ContentBlocking.shared.tld)
        manager.delegate = delegate
        return manager
    }

    private weak var delegate: ContentOverlayUserScriptDelegate?

    func setDelegate(_ delegate: ContentOverlayUserScriptDelegate?) {
        self.delegate = delegate
        autofillScript?.currentOverlayTab = delegate
    }

    private var autofillUserScriptCancellable: AnyCancellable?

    private weak var autofillScript: WebsiteAutofillUserScript? {
        didSet {
            autofillScript?.currentOverlayTab = self.delegate
        }
    }
    private var emailManager: AutofillEmailDelegate?
    private var vaultManager: AutofillSecureVaultDelegate?

    @Published var autofillDataToSave: AutofillData?

    init(autofillUserScriptPublisher: some Publisher<WebsiteAutofillUserScript?, Never>) {
        autofillUserScriptCancellable = autofillUserScriptPublisher.sink { [weak self] autofillScript in
            guard let self, let autofillScript else { return }

            self.autofillScript = autofillScript
            self.emailManager = Self.emailManagerProvider(self)
            autofillScript.emailDelegate = self.emailManager
            self.vaultManager = Self.vaultManagerProvider(self)
            autofillScript.vaultDelegate = self.vaultManager
        }
    }

    func didClick(at point: CGPoint) {
        autofillScript?.clickPoint = point
    }

}

extension AutofillTabExtension: SecureVaultManagerDelegate {

    public func secureVaultManagerIsEnabledStatus(_: SecureVaultManager) -> Bool {
        return true
    }

    func secureVaultManager(_: SecureVaultManager, promptUserToStoreAutofillData data: AutofillData, generatedPassword: Bool, trigger: AutofillUserScript.GetTriggerType?) {
        self.autofillDataToSave = data
    }

    func secureVaultManager(_: SecureVaultManager,
                            promptUserToAutofillCredentialsForDomain domain: String,
                            withAccounts accounts: [SecureVaultModels.WebsiteAccount],
                            withTrigger trigger: AutofillUserScript.GetTriggerType,
                            completionHandler: @escaping (SecureVaultModels.WebsiteAccount?) -> Void) {
        // no-op on macOS
    }

    func secureVaultManager(_: SecureVaultManager, didAutofill type: AutofillType, withObjectId objectId: String) {
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

    public func secureVaultManager(_: BrowserServicesKit.SecureVaultManager, didReceivePixel pixel: AutofillUserScript.JSPixel) {
        Pixel.fire(.jsPixel(pixel))
    }

    func secureVaultManagerShouldAutomaticallyUpdateCredentialsWithoutUsername(_: SecureVaultManager, generatedPassword: Bool) -> Bool {
        return true
    }

    func secureVaultManagerShouldAutomaticallySaveGeneratedPassword(_: SecureVaultManager) -> Bool {
        return false
    }

    func secureVaultManager(_: SecureVaultManager, promptUserToUseGeneratedPasswordForDomain: String, withGeneratedPassword generatedPassword: String, completionHandler: @escaping (Bool) -> Void) {
        // no-op on macOS
    }

    public func secureVaultManager(_: SecureVaultManager, didRequestCreditCardsManagerForDomain domain: String) {
        // no-op
    }

    public func secureVaultManager(_: SecureVaultManager, didRequestIdentitiesManagerForDomain domain: String) {
        // no-op
    }

    func secureVaultManager(_: SecureVaultManager, didRequestPasswordManagerForDomain domain: String) {
        // no-op
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

protocol AutofillProtocol {
    func setDelegate(_: ContentOverlayUserScriptDelegate?)
    func didClick(at point: CGPoint)

    var autofillDataToSavePublisher: AnyPublisher<AutofillData?, Never> { get }
    func resetAutofillData()
}

extension AutofillTabExtension: AutofillProtocol {
    func getPublicProtocol() -> AutofillProtocol { self }

    var autofillDataToSavePublisher: AnyPublisher<AutofillData?, Never> {
        self.$autofillDataToSave.eraseToAnyPublisher()
    }
    func resetAutofillData() {
        self.autofillDataToSave = nil
    }
}

extension TabExtensions {
    var autofill: AutofillProtocol? { resolve(AutofillTabExtension.self) }
}

extension Tab {

    var autofillDataToSavePublisher: AnyPublisher<AutofillData?, Never> {
        self.autofill?.autofillDataToSavePublisher.eraseToAnyPublisher() ?? Just(nil).eraseToAnyPublisher()
    }

    func resetAutofillData() {
        self.autofill?.resetAutofillData()
    }

}
