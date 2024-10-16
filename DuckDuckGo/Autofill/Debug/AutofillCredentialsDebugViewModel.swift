//
//  AutofillCredentialsDebugViewModel.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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
import Common
import os.log

final class AutofillCredentialsDebugViewModel: ObservableObject {

    struct DisplayCredentials: Identifiable {

        let tld: TLD
        let autofillDomainNameUrlMatcher: AutofillDomainNameUrlMatcher
        var credential: SecureVaultModels.WebsiteCredentials

        var id = UUID()

        var accountId: String {
            credential.account.id ?? ""
        }

        var accountTitle: String {
            credential.account.title ?? ""
        }

        var displayTitle: String {
            credential.account.name(tld: tld, autofillDomainNameUrlMatcher: autofillDomainNameUrlMatcher)
        }

        var websiteUrl: String {
            credential.account.domain ?? ""
        }

        var domain: String {
            guard let url = credential.account.domain,
                  let urlComponents = autofillDomainNameUrlMatcher.normalizeSchemeForAutofill(url),
                  let domain = urlComponents.eTLDplus1(tld: tld) ?? urlComponents.host else {
                return ""
            }
            return domain
        }

        var username: String {
            credential.account.username ?? ""
        }

        var displayPassword: String {
            return credential.password.flatMap { String(data: $0, encoding: .utf8) } ?? "FAILED TO DECODE PW"
        }

        var notes: String {
            credential.account.notes ?? ""
        }

        var created: String {
            "\(credential.account.created)"
        }

        var lastUpdated: String {
            "\(credential.account.lastUpdated)"
        }

        var lastUsed: String {
            credential.account.lastUsed != nil ? "\(credential.account.lastUsed!)" : ""
        }

        var signature: String {
            credential.account.signature ?? ""
        }
    }

    private let tld: TLD = ContentBlocking.shared.tld
    private let autofillDomainNameUrlMatcher: AutofillDomainNameUrlMatcher = AutofillDomainNameUrlMatcher()
    private var userAuthenticator: UserAuthenticating

    @Published var credentials: [DisplayCredentials] = []

    init(userAuthenticator: UserAuthenticating = DeviceAuthenticator.shared) {
        self.userAuthenticator = userAuthenticator
        beginAuthentication()
    }

    private func beginAuthentication() {
        userAuthenticator.authenticateUser(reason: .viewAllCredentials) { [weak self] authenticationResult in
            guard let self = self else {
                return
            }

            if authenticationResult.authenticated {
                self.credentials = self.loadCredentials()
            }
        }
    }

    private func loadCredentials() -> [DisplayCredentials] {
        do {
            let secureVault = try AutofillSecureVaultFactory.makeVault(reporter: SecureVaultReporter.shared)
            let accounts = try secureVault.accounts()
            var credentials: [DisplayCredentials] = []
            var accountsFailedToLoad: [String?] = []

            for account in accounts {
                guard let accountId = account.id,
                      let accountIdInt = Int64(accountId),
                      let credential = try secureVault.websiteCredentialsFor(accountId: accountIdInt) else {
                    accountsFailedToLoad.append(account.id)
                    continue
                }

                let displayCredential = DisplayCredentials(tld: tld, autofillDomainNameUrlMatcher: autofillDomainNameUrlMatcher, credential: credential)
                credentials.append(displayCredential)
            }

            if !accountsFailedToLoad.isEmpty {
                os_log("Failed to load credentials for accounts: %@", accountsFailedToLoad)
                showErrorAlertFor(accountsFailedToLoad)
            }

            return credentials
        } catch {
            os_log("Failed to fetch accounts")
            return []
        }
    }

    private func showErrorAlertFor(_ accountIds: [String?]) {
        let alert = NSAlert()
        alert.messageText = "Failed to load credentials for accounts:"
        alert.informativeText = accountIds.compactMap { $0 }.joined(separator: ", ")
        alert.alertStyle = .warning
        alert.addButton(withTitle: UserText.ok)
        alert.runModal()
    }
}
