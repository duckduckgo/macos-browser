//
//  PhishingDetectionStateManager.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

public protocol PhishingTabStateManaging {
    var didBypassError: Bool { get set }
    var isShowingPhishingError: Bool { get set }
}

public class PhishingTabStateManager: PhishingTabStateManaging {
    public var didBypassError: Bool = false
    public var isShowingPhishingError: Bool = false

    public init(){}
}

/// Any page could attempt to redirect to our Phishing Error Page duck://error?reason=phishing&url=<script>alert(1)</script>
///  This is prevented by generating a signature for each URL which can be validated without having to store each URL/token in memory.
public class PhishingRedirectTokenManager {
    static let shared = PhishingRedirectTokenManager()
    private var secretKey: String

    private init() {
        self.secretKey = PhishingRedirectTokenManager.generateRandomKey()
    }

    private static func generateRandomKey() -> String {
        var keyData = Data(count: 32) // 256-bit key
        let result = keyData.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!)
        }
        assert(result == errSecSuccess, "Failed to generate random key")
        return keyData.base64EncodedString()
    }

    func generateToken(for url: URL) -> String {
        let urlString = url.absoluteString
        let keyData = secretKey.data(using: .utf8)!
        let urlData = urlString.data(using: .utf8)!

        var hmac = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        urlData.withUnsafeBytes { urlBytes in
            keyData.withUnsafeBytes { keyBytes in
                CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA256), keyBytes.baseAddress, keyData.count, urlBytes.baseAddress, urlData.count, &hmac)
            }
        }

        let hmacData = Data(hmac)
        return hmacData.base64EncodedString()
    }

    func validateToken(_ token: String, for url: URL) -> Bool {
        let expectedToken = generateToken(for: url)
        return expectedToken == token
    }
}
