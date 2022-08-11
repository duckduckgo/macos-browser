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

final class BinaryReader {
    fileprivate var data: Data

    var bufferPosition: Int = 0

    init(data: Data) {
        self.data = data
    }

    func readSlice(length: Int) -> Data {
        let slice = data.subdata(in: bufferPosition..<bufferPosition+length)
        bufferPosition += length
        return slice
    }

    func readDoubleBE() -> Int64 {
        let data = readDoubleBE(offset: bufferPosition)
        bufferPosition += 8
        return data
    }

    func readDoubleBE(offset: Int) -> Int64 {
        let data = slice(loc: offset, len: 8)
//        let out: double_t = data.withUnsafeBytes { $0.load(as: double_t.self) }
//        return Int64(NSSwapHostDoubleToBig(Double(out)).v)
        let out: Int64 = data.reversed().withUnsafeBytes { $0.load(as: Int64.self) }
        return out
    }

    func readIntBE() -> UInt32 {
        let data = readIntBE(offset: bufferPosition)
        bufferPosition += 4
        return data
    }

    func readIntBE(offset: Int) -> UInt32 {
        let data = slice(loc: offset, len: 4)
        let out: UInt32 = data.reversed().withUnsafeBytes { $0.load(as: UInt32.self) }
        return out
    }

    func readDoubleLE() -> Int64 {
        let data = readDoubleLE(offset: bufferPosition)
        bufferPosition += 8
        return data
    }

    func readDoubleLE(offset: Int) -> Int64 {
        let data = slice(loc: offset, len: 8)
        let out: double_t = data.withUnsafeBytes { $0.load(as: double_t.self) }
        return Int64(out)
    }

    func readIntLE() -> UInt32 {
        let data = readIntLE(offset: bufferPosition)
        bufferPosition += 4
        return data
    }

    @discardableResult
    func readIntLE(offset: Int) -> UInt32 {
        let data = slice(loc: offset, len: 4)
        let out: UInt32 = data.withUnsafeBytes { $0.load(as: UInt32.self) }
        return out
    }

    func slice(loc: Int, len: Int) -> Data {
        return self.data.subdata(in: loc..<loc+len)
    }
}

enum BinaryCookiesError: Error {
    case badFileHeader
    case invalidEndOfCookieData
    case unexpectedCookieHeaderValue
}

struct Cookie {
    var expiration: Int64
    var creation: Int64
    var domain: String
    var name: String
    var path: String
    var value: String
    var secure: Bool = false
    var http: Bool = false
}

final class CookieParser {
    var numPages: UInt32 = 0
    var pageSizes: [UInt32] = []
    var pageNumCookies: [UInt32] = []
    var pageCookieOffsets: [[UInt32]] = []
    var pages: [BinaryReader] = []
    var cookieData: [[BinaryReader]] = []
    var cookies: [Cookie] = []

    var reader: BinaryReader?

    func processCookieData(data: Data) throws -> [Cookie] {
        reader = BinaryReader(data: data)

        let header = reader!.readSlice(length: 4).utf8String()

        if header == "cook" {
            getNumPages()
            getPageSizes()
            getPages()

            for index in pages.indices {
                try getNumCookies(index: index)
                getCookieOffsets(index: index)
                getCookieData(index: index)

                for cookieIndex in cookieData[index].indices {
                    try parseCookieData(cookie: cookieData[index][cookieIndex])
                }
            }
        } else {
            throw BinaryCookiesError.badFileHeader
        }

        return cookies
    }

    func parseCookieData(cookie: BinaryReader) throws {
        let macEpochOffset: Int64 = 978307199
        var offsets: [UInt32] = [UInt32]()

        cookie.readIntLE(offset: 0) // unknown
        cookie.readIntLE(offset: 4) // unknown2
        let flags = cookie.readIntLE(offset: 4 + 4) // flags
        cookie.readIntLE(offset: 8 + 4) // unknown3
        offsets.append(cookie.readIntLE(offset: 12 + 4)) // domain
        offsets.append(cookie.readIntLE(offset: 16 + 4)) // name
        offsets.append(cookie.readIntLE(offset: 20 + 4)) // path
        offsets.append(cookie.readIntLE(offset: 24 + 4)) // value

        let endOfCookie = cookie.readIntLE(offset: 28 + 4)

        if endOfCookie != 0 {
            throw BinaryCookiesError.invalidEndOfCookieData
        }

        let expiration = (cookie.readDoubleLE(offset: 32 + 8) + macEpochOffset)
        let creation = (cookie.readDoubleLE(offset: 40 + 8) + macEpochOffset)
        var domain: String = ""
        var name: String = ""
        var path: String = ""
        var value: String = ""
        var secure: Bool = false
        var http: Bool = false

        guard let cookieString = String(data: cookie.data, encoding: .ascii) else {
            throw BinaryCookiesError.invalidEndOfCookieData
        }

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

        if flags == 1 {
            secure = true
        } else if flags == 4 {
            http = true
        } else if flags == 5 {
            secure = true
            http = true
        }

        cookies.append(Cookie(expiration: expiration, creation: creation, domain: domain, name: name, path: path, value: value, secure: secure, http: http))
    }

    func getNumPages() {
        numPages = reader!.readIntBE()
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
            let cookieSize = page.readIntLE(offset: Int(cookieOffset))

            pageCookies.append(BinaryReader(data: page.slice(loc: Int(cookieOffset), len: Int(cookieSize))))
        }

        cookieData.append(pageCookies)
    }

    func getPageSizes() {
        for _ in 0..<numPages {
            pageSizes.append(reader!.readIntBE())
        }
    }

    func getPages() {
        for pageSize in pageSizes {
            pages.append(BinaryReader(data: reader!.readSlice(length: Int(pageSize))))
        }
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
