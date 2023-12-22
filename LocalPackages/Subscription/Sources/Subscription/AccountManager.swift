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
import Common

public extension Notification.Name {
    static let accountDidSignIn = Notification.Name("com.duckduckgo.subscription.AccountDidSignIn")
    static let accountDidSignOut = Notification.Name("com.duckduckgo.subscription.AccountDidSignOut")
}

public protocol AccountManagerKeychainAccessDelegate: AnyObject {
    func accountManagerKeychainAccessFailed(accessType: AccountKeychainAccessType, error: AccountKeychainAccessError)
}

public protocol AccountManaging {

    var accessToken: String? { get }

}

public class AccountManager: AccountManaging {

    private let storage: AccountStorage
    public weak var delegate: AccountManagerKeychainAccessDelegate?

    public var isUserAuthenticated: Bool {
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
        os_log(.info, log: .subscription, "[AccountManager] storeAuthToken")

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
        os_log(.info, log: .subscription, "[AccountManager] storeAccount")

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
        os_log(.info, log: .subscription, "[AccountManager] signOut")

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

    public func hasEntitlement(for name: String) async -> Bool {
        await fetchEntitlements().contains(name)
    }

    public func fetchEntitlements() async -> [String] {
        guard let accessToken else { return [] }

        switch await AuthService.validateToken(accessToken: accessToken) {
        case .success(let response):
            let entitlements = response.account.entitlements
            return entitlements.map { $0.name }

        case .failure(let error):
            os_log(.error, log: .subscription, "[AccountManager] fetchEntitlements error: %{public}@", error.localizedDescription)
            return []
        }
    }

    public func exchangeAuthTokenToAccessToken(_ authToken: String) async -> Result<String, Error> {
        switch await AuthService.getAccessToken(token: authToken) {
        case .success(let response):
            return .success(response.accessToken)
        case .failure(let error):
            os_log(.error, log: .subscription, "[AccountManager] exchangeAuthTokenToAccessToken error: %{public}@", error.localizedDescription)
            return .failure(error)
        }
    }

    public typealias AccountDetails = (email: String?, externalID: String)

    public func fetchAccountDetails(with accessToken: String) async -> Result<AccountDetails, Error> {
        switch await AuthService.validateToken(accessToken: accessToken) {
        case .success(let response):
            return .success(AccountDetails(email: response.account.email, externalID: response.account.externalID))
        case .failure(let error):
            os_log(.error, log: .subscription, "[AccountManager] fetchAccountDetails error: %{public}@", error.localizedDescription)
            return .failure(error)
        }
    }

    public func checkSubscriptionState() async {
        os_log(.info, log: .subscription, "[AccountManager] checkSubscriptionState")

        guard let token = accessToken else { return }

        if case .success(let response) = await SubscriptionService.getSubscriptionDetails(token: token) {
            if !response.isSubscriptionActive {
                signOut()
            }
        }
    }

    @discardableResult
    public static func checkForEntitlements(wait waitTime: Double, retry retryCount: Int) async -> Bool {
        var count = 0
        var hasEntitlements = false

        repeat {
            hasEntitlements = await !AccountManager().fetchEntitlements().isEmpty

            if hasEntitlements {
                break
            } else {
                count += 1
                try? await Task.sleep(seconds: waitTime)
            }
        } while !hasEntitlements && count < retryCount

        return hasEntitlements
    }
}

extension Task where Success == Never, Failure == Never {
    static func sleep(seconds: Double) async throws {
        let duration = UInt64(seconds * 1_000_000_000)
        try await Task.sleep(nanoseconds: duration)
    }
}
