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
import os.log
import Combine

// Encapsulation of third party password managers
class PasswordManagerCoordinator: BrowserServicesKit.PasswordManager {

    static let shared = PasswordManagerCoordinator()

    enum PasswordManagerCoordinatorError: Error {
        case makingOfUrlFailed
    }

    let bitwardenManagement: BWManagement = BWManager.shared

    var isEnabled: Bool {
        return bitwardenManagement.status != .disabled
    }

    var name: String {
        return "bitwarden"
    }
    
    var displayName: String {
        return "Bitwarden"
    }
    
    var username: String? {
        if case let .connected(vault: vault) = bitwardenManagement.status {
            return vault.email
        }
        return nil
    }
    
    var isLocked: Bool {
        switch bitwardenManagement.status {
        case .connected(vault: let vault): return vault.status == .locked
        case .disabled: return false
        default: return true
        }
    }

    var activeVaultEmail: String? {
        switch bitwardenManagement.status {
        case .connected(vault: let vault): return vault.email
        default: return nil
        }
    }

    var statusCancellable: AnyCancellable?

    func setEnabled(_ enabled: Bool) {
        if enabled {
            if !bitwardenManagement.status.isConnected {
                bitwardenManagement.initCommunication()
            }
        } else {
            BWManager.shared.cancelCommunication()
        }
    }

    func askToUnlock(completionHandler: @escaping () -> Void) {
        bitwardenManagement.openBitwarden()

        statusCancellable = bitwardenManagement.statusPublisher
            .receive(on: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] status in
                guard let self = self else {
                    self?.statusCancellable?.cancel()
                    return
                }

                if case let .connected(vault: vault) = status,
                   vault.status == .unlocked {
                    self.statusCancellable?.cancel()
                    self.statusCancellable = nil
                    completionHandler()
                }
            }
    }

    func openPasswordManager() {
        bitwardenManagement.openBitwarden()
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

    func cachedAccountsFor(domain: String) -> [BrowserServicesKit.SecureVaultModels.WebsiteAccount] {
        return cache
            .filter { (_, credential) in
                credential.domain == domain
            }
            .compactMap {
                SecureVaultModels.WebsiteAccount(from: $0.value)
            }
    }
    func cachedWebsiteCredentialsFor(domain: String, username: String) -> BrowserServicesKit.SecureVaultModels.WebsiteCredentials? {
        if let credential: BWCredential = cache.values.first(where: { credential in
            credential.domain == domain && credential.username == username
        }) {
            return SecureVaultModels.WebsiteCredentials(from: credential)
        }
        return nil
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

        bitwardenManagement.retrieveCredentials(for: url) { [weak self] credentials, error in
            if let error = error {
                completion([], error)
                return
            } else {
                self?.cache(credentials: credentials)
                let credentials = credentials.compactMap { BrowserServicesKit.SecureVaultModels.WebsiteCredentials(from: $0) }
                completion(credentials, nil)
            }
        }
    }

    func storeWebsiteCredentials(_ credentials: SecureVaultModels.WebsiteCredentials, completion: @escaping (Error?) -> Void)  {
        guard case let .connected(vault) = bitwardenManagement.status,
              let bitwardenCredential = BWCredential(from: credentials, vault: vault) else {
            assertionFailure("Bitwarden is not connected or bad credential")
            os_log("Failed to store credentials: Bitwarden is not connected or bad credential", type: .error)
            return
        }

        if bitwardenCredential.credentialId == nil {
            bitwardenManagement.create(credential: bitwardenCredential) { [weak self] error in
                self?.websiteCredentialsFor(domain: credentials.account.domain) { _, _ in
                    completion(error)
                }
            }
        } else {
            bitwardenManagement.update(credential: bitwardenCredential) { [weak self] error in
                self?.websiteCredentialsFor(domain: credentials.account.domain) { _, _ in
                    completion(error)
                }
            }
        }
    }

    // MARK: - Cache

    private func cache(credentials: [BWCredential]) {
        credentials.forEach { credential in
            if let credentialId = credential.credentialId {
                cache[credentialId] = credential
            }
        }
    }

    private var cache = [String: BWCredential]()

}

extension BrowserServicesKit.SecureVaultModels.WebsiteAccount {

    init?(from bitwardenCredential: BWCredential) {
        guard let credentialId = bitwardenCredential.credentialId else {
            return nil
        }
        self.init(id: credentialId,
                  username: bitwardenCredential.username ?? "",
                  domain: bitwardenCredential.domain,
                  created: Date(),
                  lastUpdated: Date())
    }

}

extension BrowserServicesKit.SecureVaultModels.WebsiteCredentials {

    init?(from bitwardenCredential: BWCredential, emptyPasswordAllowed: Bool = true) {
        guard let account = BrowserServicesKit.SecureVaultModels.WebsiteAccount(from: bitwardenCredential) else {
            assertionFailure("Failed to init account from BitwardenCredential")
            return nil
        }

        let passwordString = emptyPasswordAllowed ? bitwardenCredential.password ?? "" : bitwardenCredential.password

        guard let password = passwordString?.data(using: .utf8) else {
            assertionFailure("Failed to init account from BitwardenCredential")
            return nil
        }
        self.init(account: account, password: password)
    }

}

extension BWCredential {

    init?(from websiteCredentials: BrowserServicesKit.SecureVaultModels.WebsiteCredentials, vault: BWVault) {
        self.init(userId: vault.id,
                  credentialId: websiteCredentials.account.id,
                  credentialName: websiteCredentials.account.domain,
                  username: websiteCredentials.account.username,
                  password: websiteCredentials.password.utf8String() ?? "")
    }

}
