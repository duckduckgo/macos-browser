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

    func testWhenParsingMultipleRowsThenMultipleArraysAreReturned() throws {
        let string = """
          line 1
        line 2
        """
        let parsed = try CSVParser().parse(string: string)

        XCTAssertEqual(parsed, [["line 1"], ["line 2"]])
    }

    func testControlCharactersAreIgnored() throws {
        let string = """
        \u{FEFF}line\u{10} 1\u{10}
        line 2\u{FEFF}
        """
        let parsed = try CSVParser().parse(string: string)

        XCTAssertEqual(parsed, [["line 1"], ["line 2"]])
    }

    func testWhenParsingRowsWithVariableNumbersOfEntriesThenParsingSucceeds() throws {
        let string = """
        one
        two;three;
        four;five;six
        """
        let parsed = try CSVParser().parse(string: string)

        XCTAssertEqual(parsed, [["one"], ["two", "three", ""], ["four", "five", "six"]])
    }

    func testWhenParsingRowsSurroundedByQuotesThenQuotesAreRemoved() throws {
        let string = """
          "url","username", "password"
        """ + "  "

        let parsed = try CSVParser().parse(string: string)

        XCTAssertEqual(parsed, [["url", "username", "password"]])
    }

    func testWhenParsingMalformedCSV_ParserThrows() {
        let string = """
        "url","user"name","password"
        """

        XCTAssertThrowsError(try CSVParser().parse(string: string))
    }

    func testWhenParsingRowsWithAnEscapedQuoteThenQuoteIsUnescaped() throws {
        let string = """
        "url","username","password\\""with""quotes"
        """

        let parsed = try CSVParser().parse(string: string)

        XCTAssertEqual(parsed, [["url", "username", "password\\\"with\"quotes"]])
    }

    func testWhenParsingQuotedRowsContainingCommasThenTheyAreTreatedAsOneColumnEntry() throws {
        let string = """
        "url","username","password,with,commas"
        """

        let parsed = try CSVParser().parse(string: string)

        XCTAssertEqual(parsed, [["url", "username", "password,with,commas"]])
    }

}
