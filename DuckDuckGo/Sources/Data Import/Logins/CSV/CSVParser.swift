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

final class CSVParser {

    static func parse(string: String) -> [[String]] {
        return string.parseCSV()
    }

}

private extension String {

    func parseCSV() -> [[String]] {
        var result: [[String]] = [[]]
        var currentField = "".unicodeScalars
        var inQuotes = false
        var hasPrecedingBackslash = false

        @inline(__always) func flush() {
            result[result.endIndex - 1].append(String(currentField))
            currentField.removeAll()
        }

        for character in self.unicodeScalars {
            switch (character, inQuotes, hasPrecedingBackslash) {
            case (",", false, _):
                hasPrecedingBackslash = false
                flush()
            case ("\n", false, _):
                hasPrecedingBackslash = false
                flush()
                result.append([])
            case ("\\", true, _):
                hasPrecedingBackslash = true
            case ("\"", _, false):
                inQuotes = !inQuotes
            case ("\"", _, true):
                // The preceding characters was a backslash, so append the quote to the string instead of treating it as a delimiter
                hasPrecedingBackslash = false
                currentField.append(character)
            default:
                hasPrecedingBackslash = false
                currentField.append(character)
            }
        }

        flush()

        return result
    }

}
