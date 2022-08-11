//
//  FirefoxCookiesReader.swift
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
import GRDB

final class FirefoxCookiesReader {

    enum Constants {
        static let cookiesDatabaseName = "cookies.sqlite"
    }

    enum ImportError: Error {
        case noCookiesFileFound
        case failedToTemporarilyCopyFile
        case unexpectedCookiesDatabaseFormat
    }

    private let firefoxCookiesDatabaseURL: URL

    init(firefoxDataDirectoryURL: URL) {
        self.firefoxCookiesDatabaseURL = firefoxDataDirectoryURL.appendingPathComponent(Constants.cookiesDatabaseName)
    }

    func readCookies() -> Result<[HTTPCookie], FirefoxCookiesReader.ImportError> {
        do {
            return try firefoxCookiesDatabaseURL.withTemporaryFile { temporaryDatabaseURL in
                return readCookies(fromDatabaseURL: temporaryDatabaseURL)
            }
        } catch {
            return .failure(.failedToTemporarilyCopyFile)
        }
    }

    // MARK: - Private

    private func readCookies(fromDatabaseURL databaseURL: URL) -> Result<[HTTPCookie], FirefoxCookiesReader.ImportError> {
        do {
            let queue = try DatabaseQueue(path: databaseURL.path)

            let cookies: [Cookie] = try queue.read { database in
                guard let cookies = try? Cookie.fetchAll(database, sql: allCookiesQuery()) else {
                    throw ImportError.unexpectedCookiesDatabaseFormat
                }

                return cookies
            }

            let httpCookies = cookies.compactMap(HTTPCookie.init)

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
        let value: String?
        let domain: String?
        let path: String?
        let expiry: Date?
        let isSecure: String?
        let sameSite: String?
        let isHTTPOnly: Bool?

        init(row: Row) {
            name = row["name"]
            value = row["value"]
            domain = row["host"]
            path = row["path"]
            expiry = Date(timeIntervalSince1970: TimeInterval(row["expiry"] as Int))
            isSecure = row["isSecure"] == 1 ? "TRUE" : nil
            sameSite = row["sameSite"] != 0 ? "strict" : nil
            isHTTPOnly = row["isHttpOnly"] == 1 ? true : nil
        }
    }

    // MARK: - Database Queries

    func allCookiesQuery() -> String {
        return "SELECT name,value,host,path,expiry,isSecure,isHttpOnly,sameSite FROM moz_cookies;"
    }
}

fileprivate extension HTTPCookie {
    convenience init?(cookie: FirefoxCookiesReader.Cookie) {
        let properties: [HTTPCookiePropertyKey: Any?] = [
            .domain: cookie.domain,
            .path: cookie.path,
            .name: cookie.name,
            .value: cookie.value,
            .expires: cookie.expiry,
            .secure: cookie.isSecure,
            .sameSitePolicy: cookie.sameSite,
            .version: "1",
            .httpOnly: cookie.isHTTPOnly
        ]
        self.init(properties: properties.compactMapValues { $0 })
    }
}

fileprivate extension HTTPCookiePropertyKey {
    static let httpOnly = HTTPCookiePropertyKey("HttpOnly")
}
