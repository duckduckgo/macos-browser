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

    func testWhenParsingMalformedCsvWithExtraQuote_ParserAddsItToOutput() throws {
        let string = """
        "url","user"name","password",""
        """

        let parsed = try CSVParser().parse(string: string)

        XCTAssertEqual(parsed, [["url", #"user"name"#, "password", ""]])
    }

    func testWhenParsingRowsWithDoubleQuoteEscapedQuoteThenQuoteIsUnescaped() throws {
        let string = #"""
        "url","username","password\""with""quotes\""and/slash""\"
        """#

        let parsed = try CSVParser().parse(string: string)

        XCTAssertEqual(parsed, [["url", "username", #"password\"with"quotes\"and/slash"\"#]])
    }

    func testWhenParsingRowsWithBackslashEscapedQuoteThenQuoteIsUnescaped() throws {
        let string = #"""
        "\\","\"password\"with","quotes\","\",\",
        """#
        let parsed = try CSVParser().parse(string: string)

        XCTAssertEqual(parsed, [[#"\\"#, #""password"with"#, #"quotes\"#, #"",\"#, ""]])
    }

    func testWhenParsingRowsWithBackslashEscapedQuoteThenQuoteIsUnescaped2() throws {
        let string = #"""
                "\"",  "\"\"","\\","\"password\"with","quotes\","\",\",
        """#
        let parsed = try CSVParser().parse(string: string)

        XCTAssertEqual(parsed.map({ $0.map { $0.replacingOccurrences(of: "\\", with: "|").replacingOccurrences(of: "\"", with: "”") } }), [["\"", "\"\"", #"\\"#, #""password"with"#, #"quotes\"#, #"",\"#, ""].map { $0.replacingOccurrences(of: "\\", with: "|").replacingOccurrences(of: "\"", with: "”") }])
    }

    func testWhenParsingRowsWithUnescapedTitleAndEscapedQuoteAndEmojiThenQuoteIsUnescaped() throws {
        let string = #"""
        Title,Url,Username,Password,OTPAuth,Notes
        "A",,"",,,"It’s \\"you! 🖐 Select Edit to fill in more details, like your address and contact information.\",
        """#

        let parsed = try CSVParser().parse(string: string)

        XCTAssertEqual(parsed, [
            ["Title", "Url", "Username", "Password", "OTPAuth", "Notes"],
            ["A", "", "", "", "", #"It’s \"you! 🖐 Select Edit to fill in more details, like your address and contact information.\"#, ""]
        ])
    }

    func testWhenParsingQuotedRowsContainingCommasThenTheyAreTreatedAsOneColumnEntry() throws {
        let string = """
        "url","username","password,with,commas"
        """

        let parsed = try CSVParser().parse(string: string)

        XCTAssertEqual(parsed, [["url", "username", "password,with,commas"]])
    }

    func testWhenSingleValueWithQuotedEscapedQuoteThenQuoteIsUnescaped() throws {
        let string = #"""
        "\""
        """#

        let parsed = try CSVParser().parse(string: string)

        XCTAssertEqual(parsed, [["\""]])
    }

    func testSingleEnquotedBackslashValueIsParsedAsBackslash() throws {
        let string = #"""
        "\"
        """#

        let parsed = try CSVParser().parse(string: string)

        XCTAssertEqual(parsed, [[#"\"#]])
    }

    func testBackslashValueWithDoubleQuoteIsParsedAsBackslashWithQuote() throws {
        let string = #"""
        \""
        """#

        let parsed = try CSVParser().parse(string: string)

        XCTAssertEqual(parsed, [[#"\""#]])
    }

    func testEnquotedBackslashValueWithDoubleQuoteIsParsedAsBackslashWithQuote() throws {
        let string = #"""
        "\"""
        """#

        let parsed = try CSVParser().parse(string: string)

        XCTAssertEqual(parsed, [[#"\""#]])
    }

    func testEscapedDoubleQuote() throws {
        let string = #"""
        """"
        """#

        let parsed = try CSVParser().parse(string: string)

        XCTAssertEqual(parsed, [["\""]])
    }

    func testWhenValueIsDoubleQuotedThenQuotesAreUnescaped() throws {
        let string = #"""
        ""hello!""
        """#

        let parsed = try CSVParser().parse(string: string)

        XCTAssertEqual(parsed, [["\"hello!\""]])
    }

    func testWhenExpressionIsParsableEitherAsDoubleQuoteEscapedOrBackslashEscapedThenEqualFieldsNumberIsPreferred() throws {
        let string = #"""
        1,2,3,4,5,6,
        "\",b,c,d,e,f,
        asdf,\"",hi there!,4,5,6,
        a,b,c,d,e,f,
        """#

        let parsed = try CSVParser().parse(string: string)

        XCTAssertEqual(parsed, [
            ["1", "2", "3", "4", "5", "6", ""],
            ["\\", "b", "c", "d", "e", "f", ""],
            ["asdf", #"\""#, "hi there!", "4", "5", "6", ""],
            ["a", "b", "c", "d", "e", "f", ""],
        ])
    }

}
