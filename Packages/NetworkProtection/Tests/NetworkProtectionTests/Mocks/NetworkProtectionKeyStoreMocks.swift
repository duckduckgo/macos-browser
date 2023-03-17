//
//  NetworkProtectionKeyStoreMocks.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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
@testable import NetworkProtection

final class NetworkProtectionKeyStoreMock: NetworkProtectionKeyStore {

    var keyPair: KeyPair?

    // MARK: - NetworkProtectionKeyStore

    func currentKeyPair() -> NetworkProtection.KeyPair {
        if let keyPair = self.keyPair {
            return keyPair
        } else {
            let keyPair = KeyPair(privateKey: PrivateKey(), expirationDate: Date().addingTimeInterval(TimeInterval(24 * 60 * 60)))
            self.keyPair = keyPair
            return keyPair
        }
    }

    func updateCurrentKeyPair(newExpirationDate: Date) -> NetworkProtection.KeyPair {
        let keyPair = KeyPair(privateKey: keyPair?.privateKey ?? PrivateKey(), expirationDate: newExpirationDate)
        self.keyPair = keyPair
        return keyPair
    }

    func resetCurrentKeyPair() {
        self.keyPair = nil
    }

    // MARK: - Storage

    func storedPrivateKey() throws -> PrivateKey? {
        return keyPair?.privateKey
    }
}
