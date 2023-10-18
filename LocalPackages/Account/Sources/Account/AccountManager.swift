//
//  AccountManager.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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
import Purchase
import Common

public extension Notification.Name {
    static let accountDidSignIn = Notification.Name("com.duckduckgo.browserServicesKit.AccountDidSignIn")
    static let accountDidSignOut = Notification.Name("com.duckduckgo.browserServicesKit.AccountDidSignOut")
}

public protocol AccountManagerKeychainAccessDelegate: AnyObject {
    func accountManagerKeychainAccessFailed(accessType: AccountKeychainAccessType, error: AccountKeychainAccessError)
}

public class AccountManager {

    private let storage: AccountStorage
    public weak var delegate: AccountManagerKeychainAccessDelegate?

    public var isSignedIn: Bool {
        return accessToken != nil
    }

    public init(storage: AccountStorage = AccountKeychainStorage()) {
        self.storage = storage
    }

    public var authToken: String? {
        do {
            return try storage.getAuthToken()
        } catch {
            if let error = error as? AccountKeychainAccessError {
                delegate?.accountManagerKeychainAccessFailed(accessType: .getAuthToken, error: error)
            } else {
                assertionFailure("Expected AccountKeychainAccessError")
            }

            return nil
        }
    }
    
    public var accessToken: String? {
        do {
            return try storage.getAccessToken()
        } catch {
            if let error = error as? AccountKeychainAccessError {
                delegate?.accountManagerKeychainAccessFailed(accessType: .getAccessToken, error: error)
            } else {
                assertionFailure("Expected AccountKeychainAccessError")
            }

            return nil
        }
    }

    public var email: String? {
        do {
            return try storage.getEmail()
        } catch {
            if let error = error as? AccountKeychainAccessError {
                delegate?.accountManagerKeychainAccessFailed(accessType: .getEmail, error: error)
            } else {
                assertionFailure("Expected AccountKeychainAccessError")
            }

            return nil
        }
    }

    public var externalID: String? {
        do {
            return try storage.getExternalID()
        } catch {
            if let error = error as? AccountKeychainAccessError {
                delegate?.accountManagerKeychainAccessFailed(accessType: .getExternalID, error: error)
            } else {
                assertionFailure("Expected AccountKeychainAccessError")
            }

            return nil
        }
    }

    public func storeAuthToken(token: String) {
        do {
            try storage.store(authToken: token)
        } catch {
            if let error = error as? AccountKeychainAccessError {
                delegate?.accountManagerKeychainAccessFailed(accessType: .storeAuthToken, error: error)
            } else {
                assertionFailure("Expected AccountKeychainAccessError")
            }
        }
    }

    public func storeAccount(token: String, email: String?, externalID: String?) {
        os_log("AccountManager: storeAccount token: %@ email: %@ externalID:%@", log: .account, token, email ?? "nil", externalID ?? "nil")
        do {
            try storage.store(accessToken: token)
        } catch {
            if let error = error as? AccountKeychainAccessError {
                delegate?.accountManagerKeychainAccessFailed(accessType: .storeAccessToken, error: error)
            } else {
                assertionFailure("Expected AccountKeychainAccessError")
            }
        }

        do {
            try storage.store(email: email)
        } catch {
            if let error = error as? AccountKeychainAccessError {
                delegate?.accountManagerKeychainAccessFailed(accessType: .storeEmail, error: error)
            } else {
                assertionFailure("Expected AccountKeychainAccessError")
            }
        }

        do {
            try storage.store(externalID: externalID)
        } catch {
            if let error = error as? AccountKeychainAccessError {
                delegate?.accountManagerKeychainAccessFailed(accessType: .storeExternalID, error: error)
            } else {
                assertionFailure("Expected AccountKeychainAccessError")
            }
        }

        NotificationCenter.default.post(name: .accountDidSignIn, object: self, userInfo: nil)
    }

    public func signOut() {
        do {
            try storage.clearAuthenticationState()
        } catch {
            if let error = error as? AccountKeychainAccessError {
                delegate?.accountManagerKeychainAccessFailed(accessType: .clearAuthenticationData, error: error)
            } else {
                assertionFailure("Expected AccountKeychainAccessError")
            }
        }

        NotificationCenter.default.post(name: .accountDidSignOut, object: self, userInfo: nil)
    }

    // MARK: -

    public func signInByRestoringPastPurchases() {
        if #available(macOS 12.0, *) {
            Task {
                // Fetch most recent purchase
                guard let jwsRepresentation = await PurchaseManager.mostRecentTransaction() else { return }

                // Do the store login to get short-lived token
                let authToken: String
                switch await AuthService.storeLogin(signature: jwsRepresentation) {
                case .success(let response):
                    authToken = response.authToken
                case .failure(let error):
                    os_log("AccountManager error: %{public}@", log: .error, error.localizedDescription)
                    return
                }

                storeAuthToken(token: authToken)
                exchangeTokenAndRefreshEntitlements(with: authToken)
            }
        }
    }

    public func exchangeTokenAndRefreshEntitlements(with authToken: String) {
        Task {
            // Exchange short-lived token to a long-lived one
            let accessToken: String
            switch await AuthService.getAccessToken(token: authToken) {
            case .success(let response):
                accessToken = response.accessToken
            case .failure(let error):
                os_log("AccountManager error: %{public}@", log: .error, error.localizedDescription)
                return
            }

            // Fetch entitlements and account details and store the data
            switch await AuthService.validateToken(accessToken: accessToken) {
            case .success(let response):
                self.storeAuthToken(token: authToken)
                self.storeAccount(token: accessToken,
                                  email: response.account.email,
                                  externalID: response.account.externalID)

            case .failure(let error):
                os_log("AccountManager error: %{public}@", log: .error, error.localizedDescription)
                return
            }
        }
    }
}
