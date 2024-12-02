//
//  URLTokenValidator.swift
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
import CommonCrypto
import SpecialErrorPages

/**
 `URLTokenValidator` is responsible for generating and validating URL signatures to securely pass URLs around in Special Pages.

 This class ensures only legitimate redirects to special pages are allowed.
  - Secret key is generated randomly on each app startup, to prevent unwanted reading of the key.
  - Nonce/timestamp is implemented to mitigate replay attacks, within a 60 second window.
  - Base64URLEncoding is used since we may be passing the tokens in URL parameters.
 */
public class URLTokenValidator {
    public static let shared = URLTokenValidator()
    public var timeWindow: TimeInterval = 60
    private let secretKey: Data

    private init() {
        self.secretKey = URLTokenValidator.generateRandomKey()
    }

    /**
     Generates a random secret key for signing URLs.

     - Returns: A Data object representing the random secret key.
     */
    private static func generateRandomKey() -> Data {
        var keyData = Data(count: 32) // 256-bit key
        let result = keyData.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!)
        }
        assert(result == errSecSuccess, "Failed to generate random key")
        return keyData
    }

    /**
     Generates a token for a given URL using HMAC-SHA256.

     - Parameter url: The URL to be signed.
     - Returns: A URL-safe base64-encoded string representing the HMAC-SHA256 signature of the URL.
     */
    public func generateToken(for url: URL) -> String {
        let urlString = url.absoluteString
        let timestamp = String(Int(Date().timeIntervalSince1970))
        let dataToSign = urlString + timestamp
        let data = dataToSign.utf8data

        let hmacData = hmacSHA256(data: data, key: secretKey)
        let signature = URLTokenValidator.base64URLEncode(hmacData)
        return "\(signature):\(timestamp)"
    }

    /**
     Validates a given token for a URL.

     - Parameters:
        - token: The token to be validated.
        - url: The URL for which the token was generated.
     - Returns: A boolean indicating whether the token is valid for the given URL.
     */
    public func validateToken(_ token: String, for url: URL) -> Bool {
        let components = token.split(separator: ":")
        guard components.count == 2,
              let signature = components.first,
              let timestampString = components.last,
              let timestamp = TimeInterval(timestampString) else {
            return false
        }

        // Check if the token is within the acceptable time window
        let currentTime = Date().timeIntervalSince1970
        guard abs(currentTime - timestamp) <= timeWindow else {
            return false
        }

        let urlString = url.absoluteString
        let dataToSign = urlString + timestampString
        let data = dataToSign.data(using: .utf8)!

        let expectedHmacData = hmacSHA256(data: data, key: secretKey)
        let expectedSignature = URLTokenValidator.base64URLEncode(expectedHmacData)

        return expectedSignature == signature
    }

    /**
     Generates an HMAC-SHA256 hash for the given data using the provided key.

     - Parameters:
        - data: The data to be hashed.
        - key: The key to be used for hashing.
     - Returns: A Data object representing the HMAC-SHA256 hash.
     */
    private func hmacSHA256(data: Data, key: Data) -> Data {
        var hmac = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { dataBytes in
            key.withUnsafeBytes { keyBytes in
                CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA256), keyBytes.baseAddress, key.count, dataBytes.baseAddress, data.count, &hmac)
            }
        }
        return Data(hmac)
    }

    /**
     Encodes the given data to a URL-safe base64-encoded string.

     - Parameter data: The data to be encoded.
     - Returns: A URL-safe base64-encoded string.
     */
    public static func base64URLEncode(_ data: Data) -> String {
        let base64String = data.base64EncodedString()
        let base64URLString = base64String
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return base64URLString
    }

    public static func base64URLEncode(_ url: URL) -> String {
        let data = url.absoluteString.utf8data
        return base64URLEncode(data)
    }

    /**
     Decodes a URL-safe base64-encoded string to data.

     - Parameter base64URLString: The URL-safe base64-encoded string to be decoded.
     - Returns: The decoded data, or nil if the string is not a valid base64-encoded string.
     */
    public static func base64URLDecode(_ base64URLString: String) -> Data? {
        // Convert Base64URL string to Base64 string
        var base64String = base64URLString
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Add padding if necessary
        let paddingLength = 4 - (base64String.count % 4)
        if paddingLength < 4 {
            base64String.append(contentsOf: repeatElement("=", count: paddingLength))
        }

        // Decode the Base64 string to data
        return Data(base64Encoded: base64String)
    }
}

extension URL {
    private enum Parameter {
        static let reason = "reason"
        static let failingUrl = "url"
        static let token = "token"
    }

    init?(base64UrlString: String) {
        guard let decodedData = URLTokenValidator.base64URLDecode(base64UrlString),
              let decodedString = String(data: decodedData, encoding: .utf8),
              let url = URL(string: decodedString) else { return nil }
        self = url
    }

    var specialErrorPageParameters: (failingUrl: URL, reason: SpecialErrorKind, token: String)? {
        guard isErrorURL,
              let reason = getParameter(named: Parameter.reason).flatMap(SpecialErrorKind.init(rawValue:)),
              let failingUrl = getParameter(named: Parameter.failingUrl).flatMap(URL.init(base64UrlString:)),
              let token = getParameter(named: Parameter.token) else { return nil }

        return (failingUrl: failingUrl, reason: reason, token: token)
    }

    static func specialErrorPage(failingUrl: URL, kind: SpecialErrorKind) -> URL {
        let encodedUrl = URLTokenValidator.base64URLEncode(failingUrl)
        let token = URLTokenValidator.shared.generateToken(for: failingUrl)
        return .error.appendingParameters([
            Parameter.failingUrl: encodedUrl,
            Parameter.reason: kind.rawValue,
            Parameter.token: token
        ])
    }
}
