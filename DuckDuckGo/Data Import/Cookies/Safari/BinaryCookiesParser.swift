//
//  BinaryCookiesParser.swift
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

final class BinaryCookiesParser {

    enum BinaryCookiesError: Error {
        case cannotAccessFile
        case badFileHeader
        case invalidEndOfCookieData
        case unexpectedCookieHeaderValue
    }

    init(cookiesFileURL: URL) {
        self.fileURL = cookiesFileURL
    }

    func parse() -> Result<[Cookie], BinaryCookiesError> {
        do {
            let data = try Data(contentsOf: fileURL)
            let cookies = try processCookieData(data: data)
            return .success(cookies)
        } catch let e as BinaryCookiesError {
            return .failure(e)
        } catch {
            return .failure(.cannotAccessFile)
        }
    }

    let fileURL: URL

    private func processCookieData(data: Data) throws -> [Cookie] {
        let reader = BinaryDataReader(data: data)
        let signature = reader.readSlice(length: 4)

        guard signature.utf8String() == Const.fileSignature else {
            throw BinaryCookiesError.badFileHeader
        }

        let numberOfPages = reader.readIntBE()

        let pageSizes: [UInt32] = {
            var sizes = [UInt32]()
            for _ in 0..<numberOfPages {
                sizes.append(reader.readIntBE())
            }
            return sizes
        }()

        var pages: [BinaryDataReader] = []
        for pageSize in pageSizes {
            pages.append(BinaryDataReader(data: reader.readSlice(length: Int(pageSize))))
        }

        var cookies = [Cookie]()

        for page in pages {
            let numberOfCookies = try getNumberOfCookies(in: page)
            let cookieOffsets = getCookieOffsets(in: page, numberOfCookies: numberOfCookies)
            let pageCookies = getCookiesData(in: page, offsets: cookieOffsets)

            for cookieData in pageCookies {
                cookies.append(try parseCookieData(cookieData))
            }
        }

        return cookies
    }

    private func parseCookieData(_ cookieData: BinaryDataReader) throws -> Cookie {
        let endOfCookie = cookieData.readIntLE(at: 32)
        guard endOfCookie == Const.endOfCookie else {
            throw BinaryCookiesError.invalidEndOfCookieData
        }

        var offsets: [UInt32] = [UInt32]()

        let flags = CookieFlags(rawValue: cookieData.readIntLE(at: 8)) // flags

        offsets.append(cookieData.readIntLE(at: 16)) // domain
        offsets.append(cookieData.readIntLE(at: 20)) // name
        offsets.append(cookieData.readIntLE(at: 24)) // path
        offsets.append(cookieData.readIntLE(at: 28)) // value

        let expiration = Date(macTimestamp: cookieData.readDoubleLE(at: 40))
        let creation = Date(macTimestamp: cookieData.readDoubleLE(at: 48))

        guard let cookieString = String(data: cookieData.data, encoding: .ascii) else {
            throw BinaryCookiesError.invalidEndOfCookieData
        }

        var domain: String = ""
        var name: String = ""
        var path: String = ""
        var value: String = ""

        for (index, offset) in offsets.enumerated() {
            let offsetIndex = cookieString.index(cookieString.startIndex, offsetBy: Int(offset))
            let endOffset = cookieString.range(of: "\0", options: .caseInsensitive, range: offsetIndex..<cookieString.endIndex)!.lowerBound

            let string = String(cookieString[offsetIndex..<endOffset])

            if index == 0 {
                domain = string
            } else if index == 1 {
                name = string
            } else if index == 2 {
                path = string
            } else if index == 3 {
                value = string
            }
        }

        let secure = flags.contains(.secure)
        let http = flags.contains(.httpOnly)
        let sameSite: HTTPCookieStringPolicy? = flags.contains(.sameSiteLax) ? .sameSiteLax : nil

        return Cookie(expiration: expiration, creation: creation, domain: domain, name: name, path: path, value: value, secure: secure, http: http, sameSite: sameSite)
    }

    private func getCookieOffsets(in page: BinaryDataReader, numberOfCookies: UInt32) -> [UInt32] {
        var offsets: [UInt32] = [UInt32]()

        for _ in 0..<numberOfCookies {
            offsets.append(page.readIntLE())
        }

        return offsets
    }

    private func getNumberOfCookies(in page: BinaryDataReader) throws -> UInt32 {
        let header = page.readIntBE()

        guard header == Const.cookieHeaderValue else {
            throw BinaryCookiesError.unexpectedCookieHeaderValue
        }

        return page.readIntLE()
    }

    private func getCookiesData(in page: BinaryDataReader, offsets: [UInt32]) -> [BinaryDataReader] {
        var pageCookies: [BinaryDataReader] = [BinaryDataReader]()

        for cookieOffset in offsets {
            let cookieSize = page.readIntLE(at: Int(cookieOffset))
            pageCookies.append(BinaryDataReader(data: page.slice(loc: Int(cookieOffset), len: Int(cookieSize))))
        }

        return pageCookies
    }

    struct Cookie {
        var expiration: Date
        var creation: Date
        var domain: String
        var name: String
        var path: String
        var value: String
        var secure: Bool = false
        var http: Bool = false
        var sameSite: HTTPCookieStringPolicy?
    }
}

private extension BinaryCookiesParser {

    enum Const {
        static let fileSignature = "cook"
        static let cookieHeaderValue: UInt32 = 256
        static let endOfCookie: UInt32 = 0
    }

    struct CookieFlags: OptionSet {
        let rawValue: UInt32

        static let secure = CookieFlags(rawValue: 1 << 0)
        static let httpOnly = CookieFlags(rawValue: 1 << 2)
        static let sameSiteLax  = CookieFlags(rawValue: 1 << 3)

        init(rawValue: UInt32) {
            self.rawValue = rawValue
        }
    }
}
