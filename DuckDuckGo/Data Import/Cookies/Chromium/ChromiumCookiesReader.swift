//
//  ChromiumCookiesReader.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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
import GRDB

final class ChromiumCookiesReader {

    enum Constants {
        static let cookiesDatabaseName = "Cookies"
    }

    enum ImportError: Error {
        case noCookiesFileFound
        case failedToTemporarilyCopyFile
        case unexpectedCookiesDatabaseFormat
        case decryptionFailed
        case failedToDecodePasswordData
        case userDeniedKeychainPrompt
        case decryptionKeyAccessFailed(OSStatus)
    }

    private let processName: String
    private let chromiumCookiesDatabaseURL: URL
    private let decryptionKey: String?
    private let decryptionKeyPrompt: ChromiumKeychainPrompting

    init(
        chromiumDataDirectoryURL: URL,
        processName: String,
        decryptionKey: String? = nil,
        decryptionKeyPrompt: ChromiumKeychainPrompting = ChromiumKeychainPrompt()
    ) {
        self.chromiumCookiesDatabaseURL = chromiumDataDirectoryURL.appendingPathComponent(Constants.cookiesDatabaseName)
        self.processName = processName
        self.decryptionKey = decryptionKey
        self.decryptionKeyPrompt = decryptionKeyPrompt
    }

    func readCookies() -> Result<[HTTPCookie], ChromiumCookiesReader.ImportError> {
        let key: String

        if let decryptionKey = decryptionKey {
            key = decryptionKey
        } else {
            let keyPromptResult = decryptionKeyPrompt.promptForChromiumPasswordKeychainAccess(processName: processName)

            switch keyPromptResult {
            case .password(let passwordString): key = passwordString
            case .failedToDecodePasswordData: return .failure(.failedToDecodePasswordData)
            case .userDeniedKeychainPrompt: return .failure(.userDeniedKeychainPrompt)
            case .keychainError(let status): return .failure(.decryptionKeyAccessFailed(status))
            }
        }

        guard let derivedKey = deriveKey(from: key) else {
            return .failure(.decryptionFailed)
        }

        return readCookies(using: derivedKey)
    }

    func readCookies(using key: Data) -> Result<[HTTPCookie], ChromiumCookiesReader.ImportError> {
        do {
            return try chromiumCookiesDatabaseURL.withTemporaryFile { temporaryDatabaseURL in
                return readCookies(fromDatabaseURL: temporaryDatabaseURL, using: key)
            }
        } catch {
            return .failure(.failedToTemporarilyCopyFile)
        }
    }

    // MARK: - Private

    private func deriveKey(from password: String) -> Data? {
        return Cryptography.decryptPBKDF2(password: .utf8(password),
                                          salt: "saltysalt".data(using: .utf8)!,
                                          keyByteCount: 16,
                                          rounds: 1003,
                                          kdf: .sha1)
    }

    private func readCookies(fromDatabaseURL databaseURL: URL, using key: Data) -> Result<[HTTPCookie], ChromiumCookiesReader.ImportError> {
        do {
            let queue = try DatabaseQueue(path: databaseURL.path)

            let cookies: [Cookie] = try queue.read { database in
                guard let cookies = try? Cookie.fetchAll(database, sql: allCookiesQuery()) else {
                    throw ImportError.unexpectedCookiesDatabaseFormat
                }

                return cookies
            }

            let httpCookies = cookies.compactMap { HTTPCookie.init(cookie: $0, encryptionKey: key) }

            return .success(httpCookies)
        } catch {
            return .failure(.unexpectedCookiesDatabaseFormat)
        }
    }

    fileprivate class DatabaseCookies {
        let cookies: [Cookie]

        init(cookies: [Cookie]) {
            self.cookies = cookies
        }
    }

    fileprivate struct Cookie: FetchableRecord {
        let name: String?
        let encryptedValue: Data?
        let domain: String?
        let path: String?
        let expiry: Date?
        let isSecure: Bool
        let discard: String?
        let sameSite: String?
        let isHTTPOnly: Bool
        let port: String?

        init(row: Row) {
            name = row["name"]
            encryptedValue = row["encrypted_value"]
            domain = row["host_key"]
            path = row["path"]
            let expiryTimestamp: Int64? = row["expires_utc"]
            expiry = expiryTimestamp.flatMap(Date.init(chromiumTimestamp:))

            isSecure = row["is_secure"] == 1
            sameSite = row["samesite"] == 1 ? "strict" : nil
            isHTTPOnly = row["is_httponly"] == 1
            discard = row["is_persistent"]
            port = row["source_port"]
        }
    }

    // MARK: - Database Queries

    func allCookiesQuery() -> String {
        return "SELECT host_key,name,encrypted_value,path,expires_utc,is_secure,is_httponly,is_persistent,samesite,source_port FROM cookies;"
    }
}

fileprivate extension HTTPCookie {
    convenience init?(cookie: ChromiumCookiesReader.Cookie, encryptionKey: Data) {
        guard let encryptedValue = cookie.encryptedValue, let decryptedValue = decrypt(passwordData: encryptedValue, with: encryptionKey) else {
            return nil
        }

        let properties: [HTTPCookiePropertyKey: Any?] = [
            .domain: cookie.domain,
            .path: cookie.path,
            .name: cookie.name,
            .value: decryptedValue,
            .expires: cookie.expiry,
            .secure: cookie.isSecure,
            .sameSitePolicy: cookie.sameSite,
            .version: "1",
            .httpOnly: cookie.isHTTPOnly,
            .port: cookie.port,
            .discard: cookie.discard
        ]
        self.init(properties: properties.compactMapValues { $0 })
    }
}

fileprivate extension HTTPCookiePropertyKey {
    static let httpOnly = HTTPCookiePropertyKey("HttpOnly")
}

fileprivate extension Date {
    init(chromiumTimestamp: Int64) {
        let seconds = Int(chromiumTimestamp / 1000000)
        self.init(timeIntervalSince1970: TimeInterval(seconds) - 11644473600)
    }
}

private func decrypt(passwordData: Data, with key: Data) -> String? {
    guard passwordData.count >= 4 else {
        return nil
    }

    let trimmedPasswordData = passwordData[3...]

    guard let iv = String(repeating: " ", count: 16).data(using: .utf8),
          let decrypted = Cryptography.decryptAESCBC(data: trimmedPasswordData, key: key, iv: iv),
          passwordData.count >= 4 else {
        return nil
    }

    return String(data: decrypted, encoding: .utf8)
}
