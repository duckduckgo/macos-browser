//
//  InstructionsFormatParserTests.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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

final class InstructionsFormatParserTests: XCTestCase {

    func testOnlyTextLines() throws {
        let format = """
          line 1
        line 2
        """
        let parsed = try InstructionsFormatParser().parse(format: format)

        XCTAssertEqual(parsed, [[.text("line 1")], [.text("line 2")]])
        print(parsed)
    }

    func testLinesWithEscapedExpressions() throws {
        let format = """
          %d line %s %@
            line %ld
        %lld%s%@ line 3 %d
        """
        let parsed = try InstructionsFormatParser().parse(format: format)

        XCTAssertEqual(parsed, [
            [.number(argIndex: 1), .text("line "), .string(argIndex: 2), .text(" "), .object(argIndex: 3)],
            [.text("line "), .number(argIndex: 4)],
            [.number(argIndex: 5), .string(argIndex: 6), .object(argIndex: 7), .text(" line 3 "), .number(argIndex: 8)],
        ])
        print(parsed)
    }

    func testLinesWithIndexedEscapedExpressions() throws {
        let format = """
          %2$d line %3$s %1$@
            line %ld
        %lld%7$s%6$@ line 3 %8$d
        """
        let parsed = try InstructionsFormatParser().parse(format: format)

        XCTAssertEqual(parsed, [
            [.number(argIndex: 2), .text("line "), .string(argIndex: 3), .text(" "), .object(argIndex: 1)],
            [.text("line "), .number(argIndex: 4)],
            [.number(argIndex: 5), .string(argIndex: 7), .object(argIndex: 6), .text(" line 3 "), .number(argIndex: 8)],
        ])
        print(parsed)
    }

    func testItalicMarkdown() throws {
        let format = "st_art_ some_text “_italic_text_” text_ __italic_text__ text"
        let parsed = try InstructionsFormatParser().parse(format: format)
        XCTAssertEqual(parsed, [[.text("st_art_ some_text “"), .text("italic_text", italic: true), .text("” text_ "), .text("italic_text", italic: true), .text(" text")]])
    }

    func testItalicMarkdownMultiline() throws {
        let format = """
        some_text __italic_text_
        text_ __non_italic_text__ text
        """
        let parsed = try InstructionsFormatParser().parse(format: format)
        XCTAssertEqual(parsed, [
            [.text("some_text "), .text("italic_text_", italic: true)],
            [.text("text_ ", italic: true), .text("non_italic_text__ text", italic: false)]])
    }

    func testBoldMarkdown() throws {
        let format = "st*art* some*text *nonbold*text* text* **bold*text** text"
        let parsed = try InstructionsFormatParser().parse(format: format)
        XCTAssertEqual(parsed, [[.text("st*art* some*text *nonbold*text* text* "), .text("bold*text", bold: true), .text(" text")]])
    }

    func testBoldMarkdownMultiline() throws {
        let format = """
         *some*text* **bold*text*
        text* **non*bold*text** text **.csv**
        """
        let parsed = try InstructionsFormatParser().parse(format: format)
        XCTAssertEqual(parsed, [
            [.text("*some*text* "), .text("bold*text*", bold: true)],
            [.text("text* ", bold: true), .text("non*bold*text** text ", bold: false), .text(".csv", bold: true)]
        ])
    }

    func testMarkdownWithExpressions() throws {
        let format = """
        %d Open **%s**
        %d In a fresh tab, click %@ then **Google __Password__ Manager → Settings **
        %d Find “Export _Passwords_” and click **Download File**
        %d __Save the* passwords **file** someplace__ you can_find it (e.g., Desktop)
        %d %@
        """
        let parsed = try InstructionsFormatParser().parse(format: format)

        XCTAssertEqual(parsed[safe: 0], [.number(argIndex: 1), .text("Open "), .string(argIndex: 2, bold: true)])
        XCTAssertEqual(parsed[safe: 1], [.number(argIndex: 3), .text("In a fresh tab, click "), .object(argIndex: 4), .text(" then "), .text("Google ", bold: true), .text("Password", bold: true, italic: true), .text(" Manager → Settings ", bold: true)])
        XCTAssertEqual(parsed[safe: 2], [.number(argIndex: 5), .text("Find “Export "), .text("Passwords", italic: true), .text("” and click "), .text("Download File", bold: true)])
        XCTAssertEqual(parsed[safe: 3], [.number(argIndex: 6), .text("Save the* passwords ", italic: true), .text("file", bold: true, italic: true), .text(" someplace", italic: true), .text(" you can_find it (e.g., Desktop)")])
        XCTAssertEqual(parsed[safe: 4], [.number(argIndex: 7), .object(argIndex: 8)])
        XCTAssertNil(parsed[safe: 5])
    }

    func testInvalidEscapeSequencesThrow() {
        XCTAssertThrowsError(try InstructionsFormatParser().parse(format: "text with %z escape char"))
        XCTAssertThrowsError(try InstructionsFormatParser().parse(format: "%llld text with invalid digit"))
        XCTAssertThrowsError(try InstructionsFormatParser().parse(format: "%.2f unsupported format"))
        XCTAssertThrowsError(try InstructionsFormatParser().parse(format: "%.2d unsupported format"))
        XCTAssertThrowsError(try InstructionsFormatParser().parse(format: "%f unsupported format"))
        XCTAssertThrowsError(try InstructionsFormatParser().parse(format: "unexpected eof %"))
        XCTAssertThrowsError(try InstructionsFormatParser().parse(format: "unexpected eol %\nasdf"))
    }

}
