//
//  PasswordManagerCoordinator.swift
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

class PasswordManagerCoordinator: BrowserServicesKit.PasswordManager {

    enum PasswordManagerCoordinatorError: Error {
        case makingOfUrlFailed
    }

    let bitwardenManagement: BitwardenManagement = BitwardenManager.shared

    var isEnabled: Bool {
        return bitwardenManagement.status != .disabled
    }

    var name: String {
        return "bitwarden"
    }

    var isLocked: Bool {
        switch bitwardenManagement.status {
        case .connected(vault: let vault): return vault.status == .locked
        default: return true
        }
    }

    func askToUnlock(completionHandler: @escaping () -> Void) {
        bitwardenManagement.openBitwarden()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            completionHandler()
        }
    }

    func accountsFor(domain: String, completion: @escaping ([BrowserServicesKit.SecureVaultModels.WebsiteAccount], Error?) -> Void) {
        guard !isLocked else {
            completion([], nil)
            return
        }

        guard let url = URL(string: "https://\(domain)") else {
            completion([], PasswordManagerCoordinatorError.makingOfUrlFailed)
            return
        }

        bitwardenManagement.retrieveCredentials(for: url) { [weak self] credentials, error in
            if let error = error {
                completion([], error)
                return
            } else {
                let accounts = credentials.compactMap { return BrowserServicesKit.SecureVaultModels.WebsiteAccount(from: $0) }
                self?.cache(credentials: credentials)
                completion(accounts, nil)
            }
        }
    }

    func websiteCredentialsFor(accountId: String, completion: @escaping (BrowserServicesKit.SecureVaultModels.WebsiteCredentials?, Error?) -> Void) {
        guard !isLocked else {
            completion(nil, nil)
            return
        }

        if let credential = cache[accountId] {
            completion(BrowserServicesKit.SecureVaultModels.WebsiteCredentials(from: credential), nil)
        } else {
            assertionFailure("Credentials not cached")
            completion(nil, nil)
        }
    }

    func websiteCredentialsFor(domain: String, completion: @escaping ([BrowserServicesKit.SecureVaultModels.WebsiteCredentials], Error?) -> Void) {
        guard !isLocked else {
            completion([], nil)
            return
        }

        guard let url = URL(string: "https://\(domain)") else {
            completion([], PasswordManagerCoordinatorError.makingOfUrlFailed)
            return
        }

        bitwardenManagement.retrieveCredentials(for: url) { credentials, error in
            if let error = error {
                completion([], error)
                return
            } else {
                let credentials = credentials.compactMap { BrowserServicesKit.SecureVaultModels.WebsiteCredentials(from: $0) }
                completion(credentials, nil)
            }
        }
    }

    // MARK: - Cache

    private func cache(credentials: [BitwardenCredential]) {
        credentials.forEach { credential in
            if let credentialId = credential.credentialId {
                cache[credentialId] = credential
            }
        }
    }

    private var cache = [String: BitwardenCredential]()

}

extension BrowserServicesKit.SecureVaultModels.WebsiteAccount {

    init?(from bitwardenCredential: BitwardenCredential) {
        guard let credentialId = bitwardenCredential.credentialId else {
            return nil
        }
        self.init(id: credentialId,
                  username: bitwardenCredential.username,
                  domain: bitwardenCredential.domain,
                  created: Date(),
                  lastUpdated: Date())
    }

}

extension BrowserServicesKit.SecureVaultModels.WebsiteCredentials {

    init?(from bitwardenCredential: BitwardenCredential) {
        guard let account = BrowserServicesKit.SecureVaultModels.WebsiteAccount(from: bitwardenCredential),
        let password = bitwardenCredential.password.data(using: .utf8) else {
            return nil
        }
        self.init(account: account, password: password)
    }

}
