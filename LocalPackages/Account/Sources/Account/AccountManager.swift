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
        return token != nil
    }

    public init(storage: AccountStorage = AccountKeychainStorage()) {
        self.storage = storage
    }

    public var token: String? {
        do {
            return try storage.getToken()
        } catch {
            if let error = error as? AccountKeychainAccessError {
                delegate?.accountManagerKeychainAccessFailed(accessType: .getToken, error: error)
            } else {
                assertionFailure("Expected AccountKeychainAccessError")
            }

            return nil
        }
    }

    public var shortLivedToken: String? {
        do {
            return try storage.getShortLivedToken()
        } catch {
            if let error = error as? AccountKeychainAccessError {
                delegate?.accountManagerKeychainAccessFailed(accessType: .getShortLivedToken, error: error)
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

    public func storeShortLivedToken(token: String) {
        do {
            try storage.store(shortLivedToken: token)
        } catch {
            if let error = error as? AccountKeychainAccessError {
                delegate?.accountManagerKeychainAccessFailed(accessType: .storeToken, error: error)
            } else {
                assertionFailure("Expected AccountKeychainAccessError")
            }
        }
    }

    public func storeAccount(token: String, email: String?, externalID: String?) {
        print("[[AccountManager]] storeAccount token: \(token) email: \(email)")
        do {
            try storage.store(token: token)
        } catch {
            if let error = error as? AccountKeychainAccessError {
                delegate?.accountManagerKeychainAccessFailed(accessType: .storeToken, error: error)
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
                let shortLivedToken: String
                switch await AuthService.storeLogin(signature: jwsRepresentation) {
                case .success(let response):
                    shortLivedToken = response.authToken
                case .failure(let error):
                    print("Error: \(error)")
                    return
                }

                storeShortLivedToken(token: shortLivedToken)
                exchangeTokenAndRefreshEntitlements(with: shortLivedToken)
            }
        }
    }

    public func exchangeTokenAndRefreshEntitlements(with shortLivedToken: String) {
        Task {
            // Exchange short-lived token to a long-lived one
            let longLivedToken: String
            switch await AuthService.getAccessToken(token: shortLivedToken) {
            case .success(let response):
                longLivedToken = response.accessToken
            case .failure(let error):
                print("Error: \(error)")
                return
            }

            // Fetch entitlements and account details and store the data
            switch await AuthService.validateToken(accessToken: longLivedToken) {
            case .success(let response):
                self.storeShortLivedToken(token: shortLivedToken)
                self.storeAccount(token: longLivedToken,
                                  email: response.account.email,
                                  externalID: response.account.externalID)

            case .failure(let error):
                print("Error: \(error)")
                return
            }
        }
    }
}
