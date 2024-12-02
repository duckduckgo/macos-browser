//
//  ReleaseNotesParser.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

final class ReleaseNotesParser {

    static func parseReleaseNotes(from description: String?) -> ([String], [String]) {
        guard let description = description else { return ([], []) }

        var standardReleaseNotes = [String]()
        var privacyProReleaseNotes = [String]()

        // Patterns for the two sections with more flexible spacing
        let standardPattern = "<h3[^>]*>What's new</h3>\\s*<ul>(.*?)</ul>"
        let privacyProPattern = "<h3[^>]*>For Privacy Pro subscribers</h3>\\s*<ul>(.*?)</ul>"

        do {
            let standardRegex = try NSRegularExpression(pattern: standardPattern, options: .dotMatchesLineSeparators)
            let privacyProRegex = try NSRegularExpression(pattern: privacyProPattern, options: .dotMatchesLineSeparators)

            // Extract the standard release notes section
            if let standardMatch = standardRegex.firstMatch(in: description, options: [], range: NSRange(location: 0, length: description.utf16.count)) {
                if let range = Range(standardMatch.range(at: 1), in: description) {
                    let standardList = String(description[range])
                    standardReleaseNotes = extractListItems(from: standardList)
                }
            }

            // Extract the privacy pro release notes section
            if let privacyProMatch = privacyProRegex.firstMatch(in: description, options: [], range: NSRange(location: 0, length: description.utf16.count)) {
                if let range = Range(privacyProMatch.range(at: 1), in: description) {
                    let privacyProList = String(description[range])
                    privacyProReleaseNotes = extractListItems(from: privacyProList)
                }
            }
        } catch {
            assertionFailure("Error creating regular expression: \(error)")
        }

        return (standardReleaseNotes, privacyProReleaseNotes)
    }

    // Helper method to extract list items
    private static func extractListItems(from list: String) -> [String] {
        var items = [String]()
        let pattern = "<li>(.*?)</li>"

        do {
            let regex = try NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators)
            let matches = regex.matches(in: list, options: [], range: NSRange(location: 0, length: list.utf16.count))

            for match in matches {
                if let range = Range(match.range(at: 1), in: list) {
                    let item = String(list[range])

                    // Convert HTML to plain text
                    if let data = item.data(using: .utf8),
                       let attributedString = try? NSAttributedString(data: data,
                                                                      options: [.documentType: NSAttributedString.DocumentType.html,
                                                                                .characterEncoding: String.Encoding.utf8.rawValue],
                                                                      documentAttributes: nil) {
                        items.append(attributedString.string)
                    }
                }
            }
        } catch {
            assertionFailure("Error creating regular expression: \(error)")
        }

        return items
    }
}
