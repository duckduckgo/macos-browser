//
//  DataEncryption.swift
//
//  Copyright © 2020 DuckDuckGo. All rights reserved.
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
import CryptoKit

enum DataEncryptionError: Error {
    case invalidData
    case decryptionFailed
}

final class DataEncryption {

    static func encrypt(data: Data, key: SymmetricKey) throws -> Data {
        try ChaChaPoly.seal(data, using: key).combined
    }

    static func decrypt(data: Data, key: SymmetricKey) throws -> Data {
        do {
            let sealedBox = try ChaChaPoly.SealedBox(combined: data)
            return try ChaChaPoly.open(sealedBox, using: key)
        } catch {
            switch error {
            // This error is thrown when the sealed box cannot be created, i.e. the data has changed for some reason and can no longer be decrypted.
            case CryptoKitError.incorrectParameterSize:
                throw DataEncryptionError.invalidData
            default:
                throw DataEncryptionError.decryptionFailed
            }
        }
    }

}
