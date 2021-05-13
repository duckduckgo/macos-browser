//
//  DataHrefTests.swift
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

import Foundation
import XCTest
@testable import DuckDuckGo_Privacy_Browser

final class DataHrefTests: XCTestCase {
    var mime = ""

    override func setUp() {
        mime = ""
    }

    func testWhenMalformedDataHrefThenNilReturned() {
        let hrefs = [
            "",
            "dat:,<data>",
            "data:",
            "data:mediatype",
            "data:application/pdf;base64"
        ]

        for dataHref in hrefs {
            let data = Data(dataHref: dataHref, mimeType: &mime)
            XCTAssertNil(data, dataHref)
            XCTAssertTrue(mime.isEmpty, dataHref)
        }
    }

    func testWhenEmptyHrefHeaderAndDataThenDataIsEmpty() {
        let data = Data(dataHref: "data:,", mimeType: &mime)
        XCTAssertEqual(data?.count, 0)
        XCTAssertEqual(mime, "text/plain")
    }

    func testWhenEmptyHrefHeaderThenDataIsCorrect() {
        let data = Data(dataHref: "data:,thetext", mimeType: &mime)
        XCTAssertEqual(data, "thetext".data(using: .ascii))
        XCTAssertEqual(mime, "text/plain")
    }

    func testWhenMalformedEncodingThenDataIsCorrect() {
        let data = Data(dataHref: "data:;charset=charset,thetext", mimeType: &mime)
        XCTAssertEqual(data, "thetext".data(using: .ascii))
        XCTAssertEqual(mime, "text/plain")
    }

    func testWhenEmptyHrefDataThenDataIsEmpty() {
        let data = Data(dataHref: "data:;;,", mimeType: &mime)
        XCTAssertEqual(data?.count, 0)
        XCTAssertEqual(mime, "text/plain")
    }

    func testWhenMalformedEncodingTextDataIsCorrect() {
        let data = Data(dataHref: "data:;charset=cp1251;charset=abc;;,theяdata", mimeType: &mime)
        XCTAssertEqual(data, "theяdata".data(using: .windowsCP1251))
        XCTAssertEqual(mime, "text/plain")
    }

    func testWhenWrongEncodingTextDataIsNil() {
        let data = Data(dataHref: "data:;charset=ascii,theяdata", mimeType: &mime)
        XCTAssertNil(data)
        XCTAssertTrue(mime.isEmpty)
    }

    func testWhenBase64EncodedThenDataIsCorrect() {
        let base64 = "somedata".data(using: .utf8)!.base64EncodedString()
        let data = Data(dataHref: "data:application/some;base64,\(base64)", mimeType: &mime)
        XCTAssertEqual(data, "somedata".data(using: .utf8))
        XCTAssertEqual(mime, "application/some")
    }

    func testWhenMalformedMimeThenBase64DataIsCorrectAndMimeIsText() {
        let base64 = "somedata".data(using: .utf8)!.base64EncodedString()
        let data = Data(dataHref: "data:base64,\(base64)", mimeType: &mime)
        XCTAssertEqual(data, "somedata".data(using: .utf8))
        XCTAssertEqual(mime, "text/plain")
    }

    func testWhenNoMimeThenBase64DataIsCorrectAndMimeIsText() {
        let base64 = "somedata".data(using: .utf8)!.base64EncodedString()
        let data = Data(dataHref: "data:;base64,\(base64)", mimeType: &mime)
        XCTAssertEqual(data, "somedata".data(using: .utf8))
        XCTAssertEqual(mime, "text/plain")
    }

    func testWhenEmptyBase64fDataThenDataIsEmpty() {
        let data = Data(dataHref: "data:application/binary;base64,", mimeType: &mime)
        XCTAssertEqual(data?.count, 0)
        XCTAssertEqual(mime, "application/binary")
    }

    func testWhenMalformedBase64ThenDataIsNil() {
        let data = Data(dataHref: "data:application/binary;base64,b", mimeType: &mime)
        XCTAssertNil(data)
        XCTAssertTrue(mime.isEmpty)
    }

}
