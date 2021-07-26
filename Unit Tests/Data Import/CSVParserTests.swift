//
//  CSVParserTests.swift
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

final class CSVParserTests: XCTestCase {

    func testWhenParsingMultipleRowsThenMultipleArraysAreReturned() {
        let string = "line 1\nline 2"
        let parsed = CSVParser.parse(string: string)

        XCTAssertEqual(parsed, [["line 1"], ["line 2"]])
    }

    func testWhenParsingRowsWithVariableNumbersOfEntriesThenParsingSucceeds() {
        let string = "one\ntwo,three\nfour,five,six"
        let parsed = CSVParser.parse(string: string)

        XCTAssertEqual(parsed, [["one"], ["two", "three"], ["four", "five", "six"]])
    }

    func testWhenParsingRowsSurroundedByQuotesThenQuotesAreRemoved() {
        let string = """
        "url","username","password"
        """

        let parsed = CSVParser.parse(string: string)

        XCTAssertEqual(parsed, [["url", "username", "password"]])
    }

    func testWhenParsingRowsWithAnEscapedQuoteThenQuoteIsUnescaped() {
        let string = """
        "url","username","password\\\"with\\\"quotes"
        """

        let parsed = CSVParser.parse(string: string)

        XCTAssertEqual(parsed, [["url", "username", "password\"with\"quotes"]])
    }

    func testWhenParsingQuotedRowsContainingCommasThenTheyAreTreatedAsOneColumnEntry() {
        let string = """
        "url","username","password,with,commas"
        """

        let parsed = CSVParser.parse(string: string)

        XCTAssertEqual(parsed, [["url", "username", "password,with,commas"]])
    }

}
