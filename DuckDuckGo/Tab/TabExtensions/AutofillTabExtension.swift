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
import SecureStorage
import PixelKit

final class AutofillTabExtension: TabExtension {

    static var emailManagerProvider: (EmailManagerRequestDelegate) -> AutofillEmailDelegate = { delegate in
        let emailManager = EmailManager()
        emailManager.requestDelegate = delegate
        return emailManager
    }

    static var featureFlagger = NSApp.delegateTyped.featureFlagger

    static var vaultManagerProvider: (SecureVaultManagerDelegate) -> AutofillSecureVaultDelegate = { delegate in
        let manager = SecureVaultManager(passwordManager: PasswordManagerCoordinator.shared,
                                         includePartialAccountMatches: true,
                                         shouldAllowPartialFormSaves: featureFlagger.isFeatureOn(.autofillPartialFormSaves),
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
    private let credentialsImportManager: AutofillCredentialsImportManager
    private var passwordManagerCoordinator: PasswordManagerCoordinating = PasswordManagerCoordinator.shared
    private let privacyConfigurationManager: PrivacyConfigurationManaging = AppPrivacyFeatures.shared.contentBlocking.privacyConfigurationManager
    private let isBurner: Bool

    @Published var autofillDataToSave: AutofillData?

    init(autofillUserScriptPublisher: some Publisher<WebsiteAutofillUserScript?, Never>,
         isBurner: Bool) {
        self.isBurner = isBurner
        self.credentialsImportManager = AutofillCredentialsImportManager(isBurnerWindow: isBurner)

        autofillUserScriptCancellable = autofillUserScriptPublisher.sink { [weak self] autofillScript in
            guard let self, let autofillScript else { return }

            self.autofillScript = autofillScript
            self.emailManager = Self.emailManagerProvider(self)
            autofillScript.emailDelegate = self.emailManager
            self.vaultManager = Self.vaultManagerProvider(self)
            autofillScript.vaultDelegate = self.vaultManager
            autofillScript.passwordImportDelegate = self.credentialsImportManager
        }
    }

    func didClick(at point: CGPoint) {
        autofillScript?.clickPoint = point
    }

}

extension AutofillTabExtension: SecureVaultManagerDelegate {

    func secureVaultManagerIsEnabledStatus(_ manager: SecureVaultManager, forType type: AutofillType?) -> Bool {
        let prefs = AutofillPreferences()
        switch type {
        case .card:
            return prefs.askToSavePaymentMethods
        case .identity:
            return prefs.askToSaveAddresses
        case.password:
            return prefs.askToSaveUsernamesAndPasswords
        case .none:
            return prefs.askToSaveAddresses || prefs.askToSavePaymentMethods || prefs.askToSaveUsernamesAndPasswords
        }
    }

    func secureVaultManagerShouldSaveData(_: BrowserServicesKit.SecureVaultManager) -> Bool {
        return !isBurner
    }

    func secureVaultManager(_: SecureVaultManager, promptUserToStoreAutofillData data: AutofillData, withTrigger trigger: AutofillUserScript.GetTriggerType?) {
        self.autofillDataToSave = data
    }

    func secureVaultManager(_: SecureVaultManager,
                            promptUserToAutofillCredentialsForDomain domain: String,
                            withAccounts accounts: [SecureVaultModels.WebsiteAccount],
                            withTrigger trigger: AutofillUserScript.GetTriggerType,
                            onAccountSelected account: @escaping (SecureVaultModels.WebsiteAccount?) -> Void,
                            completionHandler: @escaping (SecureVaultModels.WebsiteAccount?) -> Void) {
        // no-op on macOS
    }

    func secureVaultManager(_: SecureVaultManager, promptUserWithGeneratedPassword password: String, completionHandler: @escaping (Bool) -> Void) {
        // no-op on macOS
    }

    public func secureVaultManager(_: SecureVaultManager,
                                   isAuthenticatedFor type: AutofillType,
                                   completionHandler: @escaping (Bool) -> Void) {

        switch type {

        // Require bio authentication for filling sensitive data via DDG password manager
        case .card, .password:
            let autofillPrefs = AutofillPreferences()
            if DeviceAuthenticator.shared.requiresAuthentication &&
                autofillPrefs.autolockLocksFormFilling &&
                autofillPrefs.passwordManager == .duckduckgo {
                DeviceAuthenticator.shared.authenticateUser(reason: .autofill) { result in
                    if case .success = result {
                        completionHandler(true)
                    } else {
                        completionHandler(false)
                    }
                }
            } else {
                completionHandler(true)
            }

        default:
            completionHandler(true)
        }

    }

    func secureVaultManager(_: SecureVaultManager, didAutofill type: AutofillType, withObjectId objectId: String) {
        PixelKit.fire(GeneralPixel.formAutofilled(kind: type.formAutofillKind))

        if type.formAutofillKind == .password &&
            passwordManagerCoordinator.isEnabled {
            passwordManagerCoordinator.reportPasswordAutofill()
        }
    }

    func secureVaultManager(_: SecureVaultManager, didRequestAuthenticationWithCompletionHandler handler: @escaping (Bool) -> Void) {
        DeviceAuthenticator.shared.authenticateUser(reason: .autofill) { authenticationResult in
            handler(authenticationResult.authenticated)
        }
    }

    func secureVaultError(_ error: SecureStorageError) {
        SecureVaultReporter.shared.secureVaultError(error)
    }

    func secureVaultKeyStoreEvent(_ event: SecureStorageKeyStoreEvent) {
        SecureVaultReporter.shared.secureVaultKeyStoreEvent(event)
    }

    public func secureVaultManager(_: BrowserServicesKit.SecureVaultManager, didReceivePixel pixel: AutofillUserScript.JSPixel) {
        PixelKit.fire(GeneralPixel.jsPixel(pixel))
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

    func secureVaultManager(_: SecureVaultManager, didRequestRuntimeConfigurationForDomain domain: String, completionHandler: @escaping (String?) -> Void) {
        let runtimeConfiguration = DefaultAutofillSourceProvider.Builder(privacyConfigurationManager: privacyConfigurationManager,
                                                                         properties: buildContentScopePropertiesForDomain(domain))
            .build()
            .buildRuntimeConfigResponse()

        completionHandler(runtimeConfiguration)
    }

    private func buildContentScopePropertiesForDomain(_ domain: String) -> ContentScopeProperties {
        var supportedFeatures = ContentScopeFeatureToggles.supportedFeaturesOnMacOS(privacyConfigurationManager.privacyConfig)

        if !passwordManagerCoordinator.isEnabled,
           AutofillNeverPromptWebsitesManager.shared.hasNeverPromptWebsitesFor(domain: domain) || isBurner {
            supportedFeatures.passwordGeneration = false
        }

        return ContentScopeProperties(gpcEnabled: WebTrackingProtectionPreferences.shared.isGPCEnabled,
                                      sessionKey: autofillScript?.sessionKey ?? "",
                                      messageSecret: autofillScript?.messageSecret ?? "",
                                      featureToggles: supportedFeatures)
    }
}

extension AutofillType {
    var formAutofillKind: GeneralPixel.FormAutofillKind {
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
