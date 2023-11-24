//
//  InstructionsParser.swift
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

import Common
import Foundation

struct InstructionsFormatParser {

    enum FormatComponent: Equatable {
        case text(String, bold: Bool = false, italic: Bool = false)
        case number
        case string(bold: Bool = false, italic: Bool = false)
        case object

        var isNumber: Bool {
            if case .number = self { true } else { false }
        }
    }

    struct ParseError: Error, LocalizedError {
        enum ErrorType: Error {
            case unexpectedEndOfText, unexpectedEndOfLine, unexpectedEscapedCharacter, escapedDigitExpected
        }

        let type: ErrorType

        let format: String
        let position: Int
        let afterText: String

        var errorDescription: String? {
            switch type {
            case .unexpectedEndOfText:
                "Unexpected end of text: expected escaped character after “\(afterText)” in pattern “\(format)”"
            case .unexpectedEndOfLine:
                "Unexpected end of line: expected escaped character after “\(afterText)” in pattern “\(format)”"
            case .unexpectedEscapedCharacter:
                "Unexpected escaped character “\(afterText.last ?? "?")” after “\(afterText)”. Supported escape sequences are: %d - line number, %s - variable string expression, %@ - image or buttom. In pattern “\(format)”"
            case .escapedDigitExpected:
                "Expected %ld or %lld, got “\(afterText)” in pattern “\(format)”"
            }
        }

    }

    func parse(format: String) throws -> [[FormatComponent]] {
        var parser = Parser()

        // TODO: pull this into parser instead
        let format = format.replacing(regex("(%)\\d+\\$(\\S)"), with: "$1$2")

        var idx: Int!
        do {
            for (index, character) in format.enumerated() {
                idx = index
                try parser.accept(character)
            }

            try parser.accept(nil)
        } catch let errorType as ParseError.ErrorType {
            throw ParseError(type: errorType, format: format, position: idx + 1,
                             afterText: String(format[format.index(format.startIndex, offsetBy: idx - min(10, idx))...format.index(format.startIndex, offsetBy: idx)]))
        }

        return parser.result
    }

    private struct Parser {
        var delimiter: Character?

        var result: [[FormatComponent]] = [[]]

        var currentLiteral = ""
        var currentEscapeSequence = ""
        var isBold = false
        var isItalic: Int = 0

        @inline(__always) mutating func append(_ character: Character) {
            currentLiteral.append(character)
            currentEscapeSequence = ""
        }

        @inline(__always) mutating func append(_ component: FormatComponent) {
            if case .text = component {} else {
                flushField()
            }
            result[result.endIndex - 1].append(component)
            currentEscapeSequence = ""
        }

        @inline(__always) mutating func flushField() {
            if !currentLiteral.isEmpty {
                append(.text(currentLiteral, bold: isBold, italic: isItalic > 0))
                currentLiteral = ""
            }
            currentEscapeSequence = ""
        }

        @inline(__always) mutating  func nextLine() {
            flushField()
            result.append([])
            currentEscapeSequence = ""
        }

        // swiftlint:disable:next cyclomatic_complexity function_body_length
        mutating func accept(_ character: Character?) throws {
            switch (currentEscapeSequence, character) {
            case ("", "%"):
                currentEscapeSequence.append("%")

            case ("%", "s"):
                append(.string(bold: isBold, italic: isItalic > 0))

            case ("%", "@"):
                append(.object)

            case ("%", "l"), ("%l", "l"):
                currentEscapeSequence.append("l")
            case ("%", "d"), ("%l", "d"), ("%ll", "d"):
                append(.number)

            case ("%", "%"):
                currentEscapeSequence = ""
                append("%")

            case ("%", _):
                throw ParseError.ErrorType.unexpectedEscapedCharacter
            case ("%l", _), ("%ll", _):
                throw ParseError.ErrorType.escapedDigitExpected

            case ("", "*"),
                ("*", "*"):
                currentEscapeSequence.append("*")

            case ("*", _): // only one `*` – reset and recurse
                append("*")
                try accept(character)

                // " " follows ** - reset and recurse
            case ("**", .some(let character)) where !character.isWordChar && !isBold:
                append("*")
                append("*")
                try accept(character)

            case ("**", _):
                flushField()
                isBold.toggle()
                try accept(character)

            case ("", "_"),
                ("_", "_"):
                currentEscapeSequence.append("_")

                // one "_" followed by non-alphanumeric – reset and recurse
            case ("_", .some(let character)) where !character.isWordChar && isItalic == 0:
                append("_")
                try accept(character)

                // one "_" followed by non-alphanumeric when italic == 1: toggle italic
            case ("_", .some(let character)) where !character.isWordChar && isItalic == 1:
                flushField()
                isItalic = 0
                try accept(character)

            case ("_", _) where isItalic == 0 && currentLiteral.last?.isWordChar != true:
                // " _word" - italic start
                flushField()
                isItalic = 1
                try accept(character)

            case ("_", _): // word continues after dash
                append("_")
                try accept(character)

                // " " follows __ - reset and recurse
            case ("__", .some(let character)) where !character.isWordChar && isItalic == 0:
                append("_")
                append("_")
                try accept(character)

            case ("__", _) where isItalic == 0:
                flushField()
                isItalic = 2
                try accept(character)

            case ("__", _) where isItalic == 2:
                flushField()
                isItalic = 0
                try accept(character)

            case (_, "\n"):
                if currentEscapeSequence.hasPrefix("%") {
                    throw ParseError.ErrorType.unexpectedEndOfLine
                }
                for character in currentEscapeSequence {
                    append(character)
                }

                nextLine()

            case (_, " ") where currentLiteral.isEmpty && (result[result.endIndex - 1].last?.isNumber ?? true):
                // trim whitespace after number or for a new line
                break

            case (_, .some(let character)):
                currentLiteral.append(character)

            case (_, .none):
                if currentEscapeSequence.hasPrefix("%") {
                    throw ParseError.ErrorType.unexpectedEndOfText
                }
                for character in currentEscapeSequence {
                    append(character)
                }

                flushField()
            }
        }
    }

}

private extension Character {

    var isWordChar: Bool {
        CharacterSet.wordCharacters.contains(unicodeScalars.first!)
    }

}

private extension CharacterSet {

    static let wordCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "%.-"))

}
