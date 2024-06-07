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

    static let kCCErrorDomain = "CommonCryptoError"

    static func decryptPBKDF2(password: EncodedString, salt: Data, keyByteCount: Int, rounds: Int, kdf: KDF) throws -> Data {
        let passwordData = try {
            switch password {
            case .base64(let string):
                return try Data(base64Encoded: string) ?? { throw NSError(domain: kCCErrorDomain, code: kCCDecodeError) }()
            case .utf8(let string):
                return string.utf8data
            }
        }()

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

        guard derivationStatus == kCCSuccess else { throw NSError(domain: kCCErrorDomain, code: Int(derivationStatus)) }

        return derivedKeyData
    }

    static func decryptAESCBC(data: Data, key: Data, iv: Data) throws -> Data {
        return try decrypt(with: CCAlgorithm(kCCAlgorithmAES128), data: data, key: key, iv: iv)
    }

    static func decrypt3DES(data: Data, key: Data, iv: Data) throws -> Data {
        return try decrypt(with: CCAlgorithm(kCCAlgorithm3DES), data: data, key: key, iv: iv)
    }

    static func decrypt(with algorithm: CCAlgorithm, data: Data, key: Data, iv: Data) throws -> Data {
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

        guard status == kCCSuccess else { throw NSError(domain: kCCErrorDomain, code: Int(status)) }

        return Data(bytes: &outBytes, count: outLength)
    }

}
