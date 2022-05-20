//
//  Cryptography.swift
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

import CommonCrypto
import CryptoKit

struct Cryptography {

    enum KDF {
        case sha1
        case sha256
    }

    enum EncodedString {
        case base64(String)
        case utf8(String)

        var string: String {
            switch self {
            case .base64(let string): return string
            case .utf8(let string): return string
            }
        }
    }

    static func decryptPBKDF2(password: EncodedString, salt: Data, keyByteCount: Int, rounds: Int, kdf: KDF) -> Data? {
        let passwordData: Data?

        switch password {
        case .base64(let string):
            passwordData = Data(base64Encoded: string)
        case .utf8(let string):
            passwordData = string.data(using: .utf8)
        }

        guard let passwordData = passwordData else {
            return nil
        }

        let passwordDataArray: [Int8] = passwordData.map { Int8(bitPattern: $0) }

        var derivedKeyData = Data(repeating: 0, count: keyByteCount)
        let derivedCount = derivedKeyData.count

        let derivationStatus: OSStatus = derivedKeyData.withUnsafeMutableBytes { derivedKeyBytes in
            let derivedKeyRawBytes = derivedKeyBytes.bindMemory(to: UInt8.self).baseAddress

            let keyDerivationAlgorithm: CCPBKDFAlgorithm

            switch kdf {
            case .sha1: keyDerivationAlgorithm = CCPBKDFAlgorithm(kCCPRFHmacAlgSHA1)
            case .sha256: keyDerivationAlgorithm = CCPBKDFAlgorithm(kCCPRFHmacAlgSHA256)
            }

            return salt.withUnsafeBytes { saltBytes in
                let rawBytes = saltBytes.bindMemory(to: UInt8.self).baseAddress
                return CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    passwordDataArray,
                    passwordDataArray.count,
                    rawBytes,
                    salt.count,
                    keyDerivationAlgorithm,
                    UInt32(rounds),
                    derivedKeyRawBytes,
                    derivedCount)
            }
        }

        return derivationStatus == kCCSuccess ? derivedKeyData : nil
    }

    static func decryptAESCBC(data: Data, key: Data, iv: Data) -> Data? {
        return decrypt(with: CCAlgorithm(kCCAlgorithmAES128), data: data, key: key, iv: iv)
    }

    static func decrypt3DES(data: Data, key: Data, iv: Data) -> Data? {
        return decrypt(with: CCAlgorithm(kCCAlgorithm3DES), data: data, key: key, iv: iv)
    }

    static func decrypt(with algorithm: CCAlgorithm, data: Data, key: Data, iv: Data) -> Data? {
        var outLength: Int = 0
        var outBytes = [UInt8](repeating: 0, count: data.count)
        var status = CCCryptorStatus(kCCSuccess)

        data.withUnsafeBytes { dataBytes in
            let dataRawBytes = dataBytes.bindMemory(to: UInt8.self).baseAddress

            iv.withUnsafeBytes { ivBytes in
                let ivRawBytes = ivBytes.bindMemory(to: UInt8.self).baseAddress

                key.withUnsafeBytes { keyBytes in
                    let keyRawBytes = keyBytes.bindMemory(to: UInt8.self).baseAddress

                    status = CCCrypt(CCOperation(kCCDecrypt),
                                     algorithm,
                                     CCOptions(kCCOptionPKCS7Padding),
                                     keyRawBytes,
                                     key.count,
                                     ivRawBytes,
                                     dataRawBytes,
                                     data.count,
                                     &outBytes,
                                     outBytes.count,
                                     &outLength)
                }
            }
        }

        guard status == kCCSuccess else {
            return nil
        }

        return Data(bytes: &outBytes, count: outLength)
    }

}
