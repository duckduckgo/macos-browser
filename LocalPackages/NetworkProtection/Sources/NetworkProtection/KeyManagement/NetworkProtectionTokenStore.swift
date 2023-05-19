//
//  NetworkProtectionTokenStore.swift
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

public protocol NetworkProtectionTokenStore {

    /// Store an oAuth token.
    ///
    func store(_ token: String)

    /// Obtain the current oAuth token.
    ///
    func fetchToken() -> String?

    /// Obtain the stored oAuth token.
    ///
    func deleteToken()
}

/// Store an oAuth token for NetworkProtection on behalf of the user. This key is then used to authenticate requests for registration and server fetches from the Network Protection backend servers.
/// Writing a new oAuth token will replace the old one.
public final class NetworkProtectionKeychainTokenStore: NetworkProtectionTokenStore {
    private let keychainStore: NetworkProtectionKeychainStore
    private let errorEvents: EventMapping<NetworkProtectionError>?

    private struct Defaults {
        static let tokenStoreService = "DuckDuckGo Network Protection Auth Token"
        static let tokenStoreName = "com.duckduckgo.networkprotection.token"
    }

    public init(useSystemKeychain: Bool,
                errorEvents: EventMapping<NetworkProtectionError>?) {
        keychainStore = NetworkProtectionKeychainStore(serviceName: Defaults.tokenStoreService,
                                                       useSystemKeychain: useSystemKeychain)
        self.errorEvents = errorEvents
    }

    public func store(_ token: String) {
        let data = token.data(using: .utf8)!
        do {
            try keychainStore.deleteAll()
            try keychainStore.writeData(data, named: Defaults.tokenStoreName)
        } catch {
            handle(error)
        }
    }

    public func fetchToken() -> String? {
        do {
            return try keychainStore.readData(named: Defaults.tokenStoreName).flatMap {
                String(data: $0, encoding: .utf8)
            }
        } catch {
            handle(error)
            return nil
        }
    }

    public func deleteToken() {
        do {
            try keychainStore.deleteAll()
        } catch {
            handle(error)
        }
    }

    // MARK: - EventMapping

    private func handle(_ error: Error) {
        guard let error = error as? NetworkProtectionKeychainStoreError else {
            assertionFailure("Failed to cast Network Protection Token store error")
            errorEvents?.fire(NetworkProtectionError.unhandledError(function: #function, line: #line, error: error))
            return
        }

        errorEvents?.fire(error.networkProtectionError)
    }
}
