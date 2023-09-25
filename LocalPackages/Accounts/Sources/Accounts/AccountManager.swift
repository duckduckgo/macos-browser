//
//  AccountManager.swift
//  DuckDuckGo
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

public extension Notification.Name {
    static let accountDidSignIn = Notification.Name("com.duckduckgo.browserServicesKit.AccountDidSignIn")
    static let accountDidSignOut = Notification.Name("com.duckduckgo.browserServicesKit.AccountDidSignOut")
}

public protocol AccountServiceStorage: AnyObject {
    func getToken() throws -> String?
    func store(token: String) throws
    func getEmail() throws -> String?
    func store(email: String?) throws
    func clearAuthenticationState() throws
}

public class AccountManager {

    private let storage: AccountServiceStorage

    public var token: String? {
        print("[[AccountManager]] token")
        do {
            return try storage.getToken()
        } catch {
            if let error = error as? AccountKeychainAccessError {
//                requestDelegate?.emailManagerKeychainAccessFailed(accessType: .getToken, error: error)
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
//                requestDelegate?.emailManagerKeychainAccessFailed(accessType: .getToken, error: error)
            } else {
                assertionFailure("Expected AccountKeychainAccessError")
            }

            return nil
        }
    }

    public var isSignedIn: Bool {
        return token != nil
    }

    public init(storage: AccountServiceStorage = AccountKeychainStorage()) {
        self.storage = storage
    }

    public func storeAccount(token: String, email: String?) {
        print("[[AccountManager]] storeAccount token: \(token) email: \(email)")
        do {
            try storage.store(token: token)
            try storage.store(email: email)
        } catch {
            if let error = error as? AccountKeychainAccessError {
//                requestDelegate?.emailManagerKeychainAccessFailed(accessType: .storeTokenUsernameCohort, error: error)
            } else {
                assertionFailure("Expected AccountKeychainAccessError")
            }
        }

        NotificationCenter.default.post(name: .accountDidSignIn, object: self, userInfo: nil)
    }

    public func signOut() {
        print("[[AccountManager]] signOut")
        do {
            try storage.clearAuthenticationState()
        } catch {
            if let error = error as? AccountKeychainAccessError {
//                self.requestDelegate?.emailManagerKeychainAccessFailed(accessType: .deleteAuthenticationState, error: error)
            } else {
                assertionFailure("Expected AccountKeychainAccessError")
            }
        }

        NotificationCenter.default.post(name: .accountDidSignOut, object: self, userInfo: nil)
    }
}
