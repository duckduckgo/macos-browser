//
//  SafariCookiesReader.swift
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

final class SafariCookiesReader {

    enum ImportError: Error {
        case noCookiesFileFound
        case failedToTemporarilyCopyFile
        case unexpectedCookiesDatabaseFormat
    }

    private let safariCookiesFileURL: URL

    init(safariCookiesFileURL: URL) {
        self.safariCookiesFileURL = safariCookiesFileURL
    }

    func readCookies() -> Result<[HTTPCookie], SafariCookiesReader.ImportError> {
        do {
            return try safariCookiesFileURL.withTemporaryFile { temporaryDatabaseURL in
                let parser = BinaryCookiesParser(cookiesFileURL: temporaryDatabaseURL)
                let cookiesResult = try parser.parse()
                switch cookiesResult {
                case .success(let cookies):
                    let httpCookies = cookies.compactMap(HTTPCookie.init(cookie:))
                    return .success(httpCookies)
                case .failure(let error):
                    print(error)
                    return .failure(.unexpectedCookiesDatabaseFormat)
                }
            }
        } catch {
            return .failure(.failedToTemporarilyCopyFile)
        }
    }
}

fileprivate extension HTTPCookie {
    convenience init?(cookie: BinaryCookiesParser.Cookie) {
        let properties: [HTTPCookiePropertyKey: Any?] = [
            .domain: cookie.domain,
            .path: cookie.path,
            .name: cookie.name,
            .value: cookie.value,
            .expires: Date(timeIntervalSince1970: cookie.expiration),
            .secure: cookie.secure ? "TRUE": "FALSE",
            .version: "1",
            .sameSitePolicy: cookie.sameSite,
            .httpOnly: cookie.http
        ]
        self.init(properties: properties.compactMapValues { $0 })
    }
}

fileprivate extension HTTPCookiePropertyKey {
    static let httpOnly = HTTPCookiePropertyKey("HttpOnly")
}
