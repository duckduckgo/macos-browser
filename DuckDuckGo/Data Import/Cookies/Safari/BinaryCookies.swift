//
//  BinaryCookies.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0(the "License")
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

struct CookieFlags: OptionSet {
    let rawValue: UInt32

    static let secure = CookieFlags(rawValue: 1 << 0)
    static let httpOnly = CookieFlags(rawValue: 1 << 2)
    static let sameSiteLax  = CookieFlags(rawValue: 1 << 3)

    init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
}

final class BinaryReader {
    fileprivate var data: Data

    var cursor: Int = 0

    init(data: Data) {
        self.data = data
    }

    func readSlice(length: Int) -> Data {
        let slice = self.slice(loc: cursor, len: length)
        cursor += length
        return slice
    }

    func readDoubleLE() -> Double {
        let data = readDoubleLE(at: cursor)
        cursor += 8
        return data
    }

    func readIntBE() -> UInt32 {
        let data = readIntBE(at: cursor)
        cursor += 4
        return data
    }

    @discardableResult
    func readIntLE() -> UInt32 {
        let data = readIntLE(at: cursor)
        cursor += 4
        return data
    }

    func readIntBE(at offset: Int) -> UInt32 {
        let data = slice(loc: offset, len: 4)
        let out: UInt32 = data.withUnsafeBytes { $0.load(as: UInt32.self) }
        return out.byteSwapped
    }

    func readDoubleLE(at offset: Int) -> Double {
        let data = slice(loc: offset, len: 8)
        let out: Double = data.withUnsafeBytes { $0.load(as: Double.self) }
        return out
    }

    @discardableResult
    func readIntLE(at offset: Int) -> UInt32 {
        let data = slice(loc: offset, len: 4)
        let out: UInt32 = data.withUnsafeBytes { $0.load(as: UInt32.self) }
        return out
    }

    func slice(loc: Int, len: Int) -> Data {
        self.data.subdata(in: loc..<loc+len)
    }
}

enum BinaryCookiesError: Error {
    case badFileHeader
    case invalidEndOfCookieData
    case unexpectedCookieHeaderValue
}

struct Cookie {
    var expiration: TimeInterval
    var creation: TimeInterval
    var domain: String
    var name: String
    var path: String
    var value: String
    var secure: Bool = false
    var http: Bool = false
    var sameSite: HTTPCookieStringPolicy?
}

final class CookieParser {

    enum Const {
        static let fileSignature = "cook"
        static let macEpochOffset: TimeInterval = 978307199
        static let endOfCookie: UInt32 = 0
    }

    var pageNumCookies: [UInt32] = []
    var pageCookieOffsets: [[UInt32]] = []
    var pages: [BinaryReader] = []
    var cookieData: [[BinaryReader]] = []
    var cookies: [Cookie] = []

    func processCookieData(data: Data) throws -> [Cookie] {
        let reader = BinaryReader(data: data)

        let signature = reader.readSlice(length: 4).utf8String()

        guard signature == Const.fileSignature else {
            throw BinaryCookiesError.badFileHeader
        }

        let numPages = reader.readIntBE()

        let pageSizes: [UInt32] = {
            var sizes = [UInt32]()
            for _ in 0..<numPages {
                sizes.append(reader.readIntBE())
            }
            return sizes
        }()

        for pageSize in pageSizes {
            pages.append(BinaryReader(data: reader.readSlice(length: Int(pageSize))))
        }

        for index in pages.indices {
            try getNumCookies(index: index)
            getCookieOffsets(index: index)
            getCookieData(index: index)

            for cookieIndex in cookieData[index].indices {
                try parseCookieData(cookie: cookieData[index][cookieIndex])
            }
        }

        return cookies
    }

    func parseCookieData(cookie: BinaryReader) throws {
        var offsets: [UInt32] = [UInt32]()

        let flags = CookieFlags(rawValue: cookie.readIntLE(at: 8)) // flags

        offsets.append(cookie.readIntLE(at: 16)) // domain
        offsets.append(cookie.readIntLE(at: 20)) // name
        offsets.append(cookie.readIntLE(at: 24)) // path
        offsets.append(cookie.readIntLE(at: 28)) // value

        let endOfCookie = cookie.readIntLE(at: 32)

        guard endOfCookie == Const.endOfCookie else {
            throw BinaryCookiesError.invalidEndOfCookieData
        }

        let expiration = cookie.readDoubleLE(at: 40) + Const.macEpochOffset
        let creation = cookie.readDoubleLE(at: 48) + Const.macEpochOffset

        guard let cookieString = String(data: cookie.data, encoding: .ascii) else {
            throw BinaryCookiesError.invalidEndOfCookieData
        }

        var domain: String = ""
        var name: String = ""
        var path: String = ""
        var value: String = ""

        for (index, offset) in offsets.enumerated() {
            let offsetIndex = cookieString.index(cookieString.startIndex, offsetBy: Int(offset))
            let endOffset = cookieString.range(of: "\u{0000}", options: .caseInsensitive, range: offsetIndex..<cookieString.endIndex)!.lowerBound

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

        cookies.append(Cookie(expiration: expiration, creation: creation, domain: domain, name: name, path: path, value: value, secure: secure, http: http, sameSite: sameSite))
    }

    func getCookieOffsets(index: Int) {
        let page = pages[index]
        var offsets: [UInt32] = [UInt32]()

        let numCookies = pageNumCookies[index]

        for _ in 0..<numCookies {
            offsets.append(page.readIntLE())
        }

        pageCookieOffsets.append(offsets)
    }

    func getNumCookies(index: Int) throws {
        let page = pages[index]

        let header = page.readIntBE()

        if header != 256 {
            throw BinaryCookiesError.unexpectedCookieHeaderValue
        }

        pageNumCookies.append(page.readIntLE())
    }

    func getCookieData(index: Int) {
        let page = pages[index]

        let cookieOffsets = pageCookieOffsets[index]

        var pageCookies: [BinaryReader] = [BinaryReader]()

        for cookieOffset in cookieOffsets {
            let cookieSize = page.readIntLE(at: Int(cookieOffset))

            pageCookies.append(BinaryReader(data: page.slice(loc: Int(cookieOffset), len: Int(cookieSize))))
        }

        cookieData.append(pageCookies)
    }
}

public class BinaryCookies {
    class func parse(cookieURL: URL) throws -> Result<[Cookie], BinaryCookiesError> {
        let parser = CookieParser()
        let data = try Data(contentsOf: cookieURL)

        do {
            let cookies = try parser.processCookieData(data: data)
            return .success(cookies)
        } catch let e as BinaryCookiesError {
            return .failure(e)
        }
    }
}
