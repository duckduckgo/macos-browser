//
//  CSVParser.swift
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

struct CSVParser {

    enum ParserError: Error {
        case unexpectedCharacterAfterQuote(Character)
    }

    func parse(string: String) throws -> [[String]] {
        var parser = Parser()

        for character in string {
            try parser.accept(character)
        }

        parser.flushField()

        return parser.result
    }

    private enum State {
        case start
        case field
        case enquotedField
    }

    private struct Parser {
        var delimiter: Character?

        var result: [[String]] = [[]]

        var state = State.start
        var hasPrecedingQuote = false

        var currentField = ""

        @inline(__always) mutating func flushField() {
            result[result.endIndex - 1].append(currentField)
            currentField = ""
            state = .start
            hasPrecedingQuote = false
        }

        @inline(__always) mutating  func nextLine() {
            flushField()
            result.append([])
            state = .start
            hasPrecedingQuote = false
        }

        // swiftlint:disable:next cyclomatic_complexity
        mutating func accept(_ character: Character) throws {
            switch (state, character.kind(delimiter: delimiter), precedingQuote: hasPrecedingQuote) {
            case (_, .unsupported, _):
                return // skip control characters

            // expecting field start
            case (.start, .quote, _):
                state = .enquotedField
            case (.start, .delimiter, _):
                flushField()
                delimiter = character

            case (.start, .whitespace, _):
                return // trim leading whitespaces
            case (.start, .newline, _):
                nextLine()
            case (.start, _, _):
                state = .field
                currentField.append(character)

            // quote in field body is escaped with 2 quotes
            case (_, .quote, precedingQuote: false):
                hasPrecedingQuote = true
            case (_, .quote, precedingQuote: true):
                currentField.append(character)
                hasPrecedingQuote = false

            // enquoted field end
            case (.enquotedField, .delimiter, precedingQuote: true):
                flushField()
                delimiter = character

            case (.enquotedField, .newline, precedingQuote: true):
                nextLine()
            case (.enquotedField, .whitespace, precedingQuote: true):
                return // trim whitespaces between fields

            // unbalanced quote
            case (_, _, precedingQuote: true):
                // only expecting a second quote after a quote in field body
                throw ParserError.unexpectedCharacterAfterQuote(character)

            // non-enquoted field end
            case (.field, .delimiter, _):
                flushField()
                delimiter = character

            case (.field, _, _) where character.isNewline:
                nextLine()

            case (_, _, precedingQuote: false):
                currentField.append(character)
            }
        }
    }

}

private extension Character {

    enum Kind {
    case quote
    case delimiter
    case newline
    case whitespace
    case unsupported
    case other
    }

    func kind(delimiter: Character?) -> Kind {
        if self == "\"" {
            .quote
        } else if self.unicodeScalars.contains(where: { CharacterSet.unsupportedCharacters.contains($0) }) {
            .unsupported
        } else if CharacterSet.newlines.contains(unicodeScalars.first!) {
            .newline
        } else if CharacterSet.whitespaces.contains(unicodeScalars.first!) {
            .whitespace
        } else if self == delimiter || (delimiter == nil && CharacterSet.delimiters.contains(unicodeScalars.first!)) {
            .delimiter
        } else {
            .other
        }
    }

}

private extension CharacterSet {

    static let unsupportedCharacters = CharacterSet.controlCharacters.union(.illegalCharacters).subtracting(.newlines)
    static let delimiters = CharacterSet(charactersIn: ",;")

}
