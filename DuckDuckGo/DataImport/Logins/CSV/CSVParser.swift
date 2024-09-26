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

    func parse(string: String) throws -> [[String]] {
        var parser = Parser()

        for character in string {
            try Task.checkCancellation()
            // errors are only handled at the Parser level in `.branching` state
            try? parser.accept(character)
        }

        // errors are only handled at the Parser level in `.branching` state
        try? parser.flushField(final: true)

        return parser.result
    }

    private enum State {
        case start
        case field
        case enquotedField
        case branching([Parser])

        /// returns: `true` if case is `.branching`
        mutating func performIfBranching(_ action: (inout Parser) throws -> Void) -> Bool {
            guard case .branching(var parsers) = self else { return false }

            for idx in parsers.indices.reversed() {
                do {
                    try action(&parsers[idx])
                } catch {
                    parsers.remove(at: idx)
                }
            }
            self = .branching(parsers)
            return true
        }
    }

    private struct Parser {
        var delimiter: Character?

        enum QuoteEscapingType {
            case unknown
            case doubleQuote
            case backslash
        }
        var quoteEscapingType = QuoteEscapingType.unknown

        var result: [[String]] = [[]]

        var state = State.start
        enum PrecedingCharKind {
            case none
            case quote
            case backslash
        }
        var precedingCharKind = PrecedingCharKind.none

        var currentField = ""

        enum ParserError: Error {
            case unexpectedCharacterAfterQuote(Character)
            case nonEnquotedFieldPayloadStart(Character)
            case unexpectedDoubleQuoteInBackslashEscapedQuoteMode
            case unexpectedEOF
        }

        init() {}

        private func copy(applying action: (inout Self) -> Void) -> Self {
            var copy = self
            action(&copy)
            return copy
        }

        @inline(__always) mutating func flushField(final: Bool = false) throws {
            if state.performIfBranching({ try $0.flushField(final: final) }) {
                guard case .branching(let parsers) = state else { fatalError("Unexpected state") }
                if parsers.count == 1 {
                    self = parsers[0]
                } else if final,
                          let bestResult = parsers.max(by: { $0.result.reduce(0, { $0 + $1.count }) < $1.result.reduce(0, { $0 + $1.count }) }) {
                    // not expected corner case: branching parser state at the EOF
                    // find parser resulting with most fields
                    self = bestResult
                }
                return
            }
            result[result.endIndex - 1].append(currentField)

            let lastState = state
            let lastPrecedingCharKind = precedingCharKind

            currentField = ""
            state = .start
            precedingCharKind = .none

            if final, case .enquotedField = lastState, lastPrecedingCharKind != .quote {
                throw ParserError.unexpectedEOF
            }
        }

        @inline(__always) mutating func nextLine() throws {
            try flushField()
            result.append([])
            state = .start
            precedingCharKind = .none
        }

        mutating func accept(_ character: Character) throws {
            if state.performIfBranching({ try $0.accept(character) }) {
                if case .branching(let parsers) = state, parsers.count == 1 {
                    self = parsers[0]
                }
                return
            }

            let kind = character.kind(delimiter: delimiter)
            switch (state, kind, preceding: precedingCharKind, quoteEscaping: quoteEscapingType) {
            case (_, .unsupported, _, _):
                return // skip control characters

            // expecting field start
            case (.start, .quote, _, _):
                // enquoted field starting
                state = .enquotedField
            case (.start, .delimiter, _, _):
                // empty field
                try flushField()
                delimiter = character
            case (.start, .whitespace, _, _):
                return // trim leading whitespaces
            case (.start, .newline, _, _):
                try nextLine()
            case (.start, .payload, _, quoteEscaping: .backslash):
                // all non-empty fields should be enquoted in backslash-escaped-quote mode
                state = .field
                currentField.append(character)
                throw ParserError.nonEnquotedFieldPayloadStart(character)
            case (.start, .payload, _, _), (.start, .backslash, _, _):
                state = .field
                currentField.append(character)

            // handle backslash
            case (.enquotedField, .backslash, preceding: .none, quoteEscaping: .unknown),
                 (.enquotedField, .backslash, preceding: .none, quoteEscaping: .backslash):
                precedingCharKind = .backslash

            case (.enquotedField, .quote, preceding: .backslash, quoteEscaping: .unknown):
                // `\"` received in an unknown `quoteEscaping` state.
                // It may be either just a backslash-escaped quote or a `\` followed by a field end - `"\n` or `",`.
                // To figure the right way we do branching:
                // branch that finishes without errors will be the chosen one.
                state = .branching([
                    // one parser will continue parsing in backslash-escaped-quote mode
                    copy {
                        $0.quoteEscapingType = .backslash
                    },
                    // - another one will continue parsing in double-quote-escaped mode
                    copy{
                        $0.quoteEscapingType = .doubleQuote
                        // take the backslash as a payload
                        $0.currentField.append("\\")
                        $0.precedingCharKind = .none
                    }
                ])
                try self.accept(character) // feed the quote character to the parsers

            case (.enquotedField, .quote, preceding: .backslash, quoteEscaping: .backslash):
                // `\"` received in backslash-escaped-quote mode
                // it either means an escaped quote or a backslash followed by a field ending quote.
                // To figure the right way we do branching:
                // branch that finishes without errors will be the chosen one.
                state = .branching([
                    // - one parser will finish the field and continue parsing
                    copy {
                        // take the backslash as a payload at the end of the field
                        $0.currentField.append("\\")
                        // delimeter received next will finish the field
                        $0.precedingCharKind = .quote
                    },
                    // - another one will unescape the quote and continue parsing the field
                    copy {
                        // append the quote and resume building the field
                        $0.currentField.append(character /* quote */)
                        $0.precedingCharKind = .none
                    }
                ])

            case (_, _, preceding: .backslash, _):
                // any non-quote character following a backslash: it was just a backslash
                precedingCharKind = .none
                currentField.append("\\")
                try self.accept(character) // feed the character again

            // quote in field body is escaped with 2 quotes (or with a backslash)
            case (_, .quote, preceding: .none, _):
                precedingCharKind = .quote
            case (_, .quote, preceding: .quote, quoteEscaping: .unknown),
                 (_, .quote, preceding: .quote, quoteEscaping: .doubleQuote):
                currentField.append(character /* quote */)
                precedingCharKind = .none
                quoteEscapingType = .doubleQuote

            // double quotes not allowed in backslash-escaped-quote mode
            case (.enquotedField, .quote, preceding: .quote, quoteEscaping: .backslash):
                precedingCharKind = .quote
                currentField.append(character /* quote */)
                throw ParserError.unexpectedDoubleQuoteInBackslashEscapedQuoteMode

            // enquoted field end
            case (.enquotedField, .delimiter, .quote, _):
                try flushField()
                delimiter = character
            case (.enquotedField, .newline, preceding: .quote, _):
                try nextLine()
            case (.enquotedField, .whitespace, preceding: .quote, _):
                return // trim whitespaces between fields

            // unbalanced quote
            case (_, _, preceding: .quote, _):
                // only expecting a second quote after a quote in field body
                currentField.append("\"")
                currentField.append(character)
                precedingCharKind = .none
                throw ParserError.unexpectedCharacterAfterQuote(character)

            // non-enquoted field end
            case (.field, .delimiter, _, _):
                try flushField()
                delimiter = character
            case (.field, .newline, _, _):
                try nextLine()

            default:
                currentField.append(character)
            }
        }
    }

}

private extension Character {

    enum Kind {
    case backslash
    case quote
    case delimiter
    case newline
    case whitespace
    case unsupported
    case payload
    }

    func kind(delimiter: Character?) -> Kind {
        if self == "\\" {
            .backslash
        } else if self == "\"" {
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
            .payload
        }
    }

}

private extension CharacterSet {

    static let unsupportedCharacters = CharacterSet.controlCharacters.union(.illegalCharacters).subtracting(.newlines)
    static let delimiters = CharacterSet(charactersIn: ",;")

}
