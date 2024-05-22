//
//  StringExtension.swift
//
//  Copyright © 2020 DuckDuckGo. All rights reserved.
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

import BrowserServicesKit
import Common
import Foundation
import UniformTypeIdentifiers

extension RegEx {
    static let email = regex(#"[a-zA-Z0-9]+(?:\.[a-zA-Z0-9]+)*@[a-zA-Z0-9]+(?:\.[a-zA-Z0-9]+)+"#)
}

extension String {

    // MARK: - General

    func truncated(length: Int, trailing: String = "…") -> String {
      return (self.count > length) ? self.prefix(length) + trailing : self
    }

    func escapedJavaScriptString() -> String {
        self.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    private static let unicodeHtmlCharactersMapping: [Character: String] = [
        "&": "&amp;",
        "\"": "&quot;",
        "'": "&apos;",
        "<": "&lt;",
        ">": "&gt;",
        "/": "&#x2F;",
        "!": "&excl;",
        "$": "&#36;",
        "%": "&percnt;",
        "=": "&#61;",
        "#": "&#35;",
        "@": "&#64;",
        "[": "&#91;",
        "\\": "&#92;",
        "]": "&#93;",
        "^": "&#94;",
        "`": "&#97;",
        "{": "&#123;",
        "}": "&#125;",
    ]
    func escapedUnicodeHtmlString() -> String {
        var result = ""

        for character in self {
            if let mapped = Self.unicodeHtmlCharactersMapping[character] {
                result.append(mapped)
            } else {
                result.append(character)
            }
        }

        return result
    }

    func replacingInvalidFileNameCharacters(with replacement: String = "_") -> String {
        replacingOccurrences(of: "[~#@*+%{}<>\\[\\]|\"\\_^\\/:\\\\]", with: replacement, options: .regularExpression)
    }

    init(_ staticString: StaticString) {
        self = staticString.withUTF8Buffer {
            String(decoding: $0, as: UTF8.self)
        }
    }

    var utf8data: Data {
        data(using: .utf8)!
    }

    // MARK: - URL

    var url: URL? {
        return URL(trimmedAddressBarString: self)
    }

    static let localhost = "localhost"

    func dropSubdomain() -> String? {
        let parts = components(separatedBy: ".")
        guard parts.count > 1 else { return nil }
        return parts.dropFirst().joined(separator: ".")
    }

    static func uniqueFilename(for fileType: UTType? = nil) -> String {
        let fileName = UUID().uuidString

        if let ext = fileType?.preferredFilenameExtension {
            return fileName.appending("." + ext)
        }

        return fileName
    }

    var pathExtension: String {
        (self as NSString).pathExtension
    }

    var lastPathComponent: String {
        (self as NSString).lastPathComponent
    }

    func appendingPathComponent(_ component: String) -> String {
        (self as NSString).appendingPathComponent(component)
    }

    func appendingPathExtension(_ pathExtension: String?) -> String {
        guard let pathExtension, !pathExtension.isEmpty else { return self }
        return self + "." + pathExtension
    }

    private enum FileRegex {
        //                           "(matching url/file/path/at/in..-like prefix)(not an end of expr)(=|:)  (open quote/brace)
        static let varStart = regex(#"(?:url\b|\bfile\b|path\b|\bin\b|\bfrom\b|\bat)[^.,;?!"'`\])}]\s*[:= ]?\s*["'“`\[({]?"#, .caseInsensitive)
        static let closingQuotes = [
            "\"": regex(#""[,.;:]?(?:\s|$)|$"#),
            "'": regex(#"'[,.;:]?(?:\s|$)|$"#),
            "“": regex(#"”[,.;:]?(?:\s|$)|$"#),
            "`": regex(#"`[,.;:]?(?:\s|$)|$"#),
            "[": regex(#"`[,.;:]?(?:\s|$)|$"#),
            "{": regex(#"`[,.;:]?(?:\s|$)|$"#),
            "(": regex(#"`[,.;:]?(?:\s|$)|$"#),
        ]
        static let leadingSlash = regex(#"\s(\/)"#)
        static let trailingSlash = regex(#"[^\s](\/)"#)
        static let filePathBound = regex(#"([\p{L}\p{N}])[.,;:\])}](?:\s\w+|$)"#)
        static let fileExt = regex(#"(\.\w{1,15})(?:[.,;:\])}\s]|$)"#)

        static let filePathStart = regex(#"/[\p{L}\p{N}._+]"#)
        static let urlScheme = regex(#"\w+:$"#)

        static let fileName = regex(#"([\p{L}\p{N}._+]+\.\w{1,15})(?:$|\s|[.,;:\])}])"#)

        static let lineNumber = regex(#":\d+$"#)
        static let trailingSpaces = regex(#"\s+$"#)
    }

    /// find all the substring ranges looking like a file path
    func rangesOfFilePaths() -> [Range<String.Index>] { // swiftlint:disable:this cyclomatic_complexity function_body_length
        var result = IndexSet()

        func dropLineNumberAndTrimSpaces(_ range: inout Range<String.Index>) {
            if let lineNumberRange = self.firstMatch(of: FileRegex.lineNumber, range: range)?.range(in: self) {
                range = range.lowerBound..<lineNumberRange.lowerBound
            }
            if let trailingSpacesRange = self.firstMatch(of: FileRegex.trailingSpaces, range: range)?.range(in: self) {
                range = range.lowerBound..<trailingSpacesRange.lowerBound
            }
        }

        var searchRange = startIndex..<endIndex
        // find all expressions like `file=filename.ext` and similar
        while !searchRange.isEmpty {
            // find path start
            guard let matchRange = self.firstMatch(of: FileRegex.varStart, range: searchRange)?.range(in: self) else { break }
            // adjust search range
            searchRange = matchRange.upperBound..<endIndex

            // possible quote or brace character index
            let openingCharIdx = self.index(before: matchRange.upperBound)
            var resultRange: Range<String.Index>
            var isCertainlyFilePath = false
            // if the path is enquoted – find trailing quote
            if ["\"", "'", "“", "`", "(", "[", "{"].contains(self[openingCharIdx]) {
                isCertainlyFilePath = self[matchRange].localizedCaseInsensitiveContains("file") || self[matchRange].localizedCaseInsensitiveContains("path")
                searchRange = matchRange.upperBound..<endIndex

                let endRegex = FileRegex.closingQuotes[String(self[openingCharIdx])]!
                resultRange = matchRange.upperBound..<(self.firstMatch(of: endRegex, range: searchRange)?.range(in: self)?.lowerBound ?? endIndex)

            } else {
                // the task becomes harder: there‘s no opening quote, apply some file path matching heuristics
                let pathEndIdx = self.findFilePathEnd(from: matchRange.upperBound)

                // is there something like `file included from /Volumes…`? try finding the leading slash
                if let leadingSlashIdx = self.firstMatch(of: FileRegex.leadingSlash, range: matchRange.upperBound..<pathEndIdx)?.range(in: self),
                   // should be no slashes in between
                   self.range(of: "/", range: matchRange.upperBound..<leadingSlashIdx.lowerBound) == nil {
                    resultRange = self.index(after: leadingSlashIdx.lowerBound)..<pathEndIdx
                } else {
                    resultRange = matchRange.upperBound..<pathEndIdx
                }
            }
            dropLineNumberAndTrimSpaces(&resultRange)
            searchRange = resultRange.upperBound..<endIndex

            // look backwards for a possible URL scheme
            if let schemeRange = self.firstMatch(of: FileRegex.urlScheme, range: startIndex..<resultRange.lowerBound)?.range(in: self) {
                resultRange = schemeRange.lowerBound..<resultRange.upperBound
            }

            // does it look like a valid file path?
            guard isCertainlyFilePath
                    || self[resultRange].contains("/")
                    || String(self[resultRange]).matches(FileRegex.fileName)
                    || String(self[resultRange]).matches(FileRegex.fileExt) else { continue }

            guard let pathRange = Range(NSRange(resultRange, in: self)), pathRange.count > 2 else { continue }
            // collect the result
            result.insert(integersIn: pathRange)
        }

        // next find all non-matched expressions looking like a file path
        // 1. find `/something` pattern
        for match in FileRegex.filePathStart.matches(in: self, range: fullRange) {
            guard let matchIndices = Range(match.range), let matchRange = Range(match.range, in: self),
                  !result.intersects(integersIn: matchIndices) else { continue /* already matched */ }

            // 2. look backwards for possibly relative path first component start (limited by a whitespace or newline)
            var pathStartIdx = self.rangeOfCharacter(from: .whitespacesAndNewlines, options: .backwards, range: startIndex..<matchRange.lowerBound)?.upperBound ?? startIndex
            // 3. look backwards for a possible URL scheme
            if let schemeRange = self.firstMatch(of: FileRegex.urlScheme, range: startIndex..<pathStartIdx)?.range(in: self) {
                pathStartIdx = schemeRange.lowerBound
            }
            // 4. heuristically find the end of the path
            let pathEndIdx = self.findFilePathEnd(from: pathStartIdx)

            var resultRange = pathStartIdx..<pathEndIdx
            dropLineNumberAndTrimSpaces(&resultRange)

            guard let pathRange = Range(NSRange(resultRange, in: self)), pathRange.count > 2 else { continue }
            // collect the result
            result.insert(integersIn: pathRange)
        }

        // next find all non-matched expressions looking like a file name (filename.ext)
        for match in FileRegex.fileName.matches(in: self, range: fullRange) {
            guard let matchIndices = Range(match.range(at: 1)), matchIndices.count > 2, var matchRange = Range(match.range, in: self),
                  !result.intersects(integersIn: matchIndices) else { continue /* already matched */ }

            dropLineNumberAndTrimSpaces(&matchRange)

            guard let pathRange = Range(NSRange(matchRange, in: self)), pathRange.count > 2 else { continue }
            // collect the result
            result.insert(integersIn: pathRange)
        }

        return result.rangeView.compactMap {
            guard let range = Range(NSRange($0), in: self) else {
                assertionFailure("Could not convert \($0) to Range in \(self)")
                return nil
            }
            return range
        }
    }

    private func findFilePathEnd(from pathStartIdx: String.Index) -> String.Index {
        // macOS file names can contain literally any Unicode character except `/` and newline with max length=255
        // but let‘s assume some general naming conventions:
        // - `filename.extension` followed by a word boundary [ ,.:;], not `/`, terminates the file path
        // - file/folder names should not contain trailing spaces
        //   although technically it‘s possible, but if the next path component starts with `/` we'll treat it as another path
        //
        // 1. find end of the line
        let lineEnd = self.rangeOfCharacter(from: .newlines, range: pathStartIdx..<endIndex)?.lowerBound ?? endIndex

        // 2. find a boundary of the path component
        var componentStart = pathStartIdx
        while componentStart < lineEnd {
            let pathCompEnd = self.distance(from: componentStart, to: lineEnd) < 255 ? lineEnd : self.index(componentStart, offsetBy: 255)

            guard let nextSlashIdx = self.firstMatch(of: FileRegex.trailingSlash, range: componentStart..<pathCompEnd)?.range(in: self)?.upperBound else {
                // no next slash, find the most probable file name end
                let fileExtEnd = self.firstMatch(of: FileRegex.fileExt, range: componentStart..<pathCompEnd)?.range(at: 1, in: self)?.upperBound ?? pathCompEnd
                let boundary = self.firstMatch(of: FileRegex.filePathBound, range: componentStart..<pathCompEnd)?.range(at: 1, in: self)?.upperBound ?? pathCompEnd
                return min(boundary, fileExtEnd)
            }

            // does it look like like a normal path component?
            // assume if we find something like `filename; next_word` - it would mean the end of the file path
            if let boundRange = self.firstMatch(of: FileRegex.filePathBound, range: componentStart..<nextSlashIdx)?.range(at: 1, in: self)?.upperBound {
                return boundRange
            } else {
                // continue with the next path component
                componentStart = nextSlashIdx
            }
        }
        return lineEnd
    }

    func sanitized() -> String {
        var message = self

        // find all the substring ranges looking like a file path
        let pathRanges = message.rangesOfFilePaths()

        let moduleNamePrefix = #fileID.split(separator: "/")[0] + "/"
        let bundleUrlPrefix = Bundle.main.bundleURL.absoluteString
        let bundlePathPrefix = Bundle.main.bundlePath + "/"
        let allowedExtensions = ["swift", "m", "mm", "c", "cpp", "js", "go", "o", "a", "framework", "lib", "dylib", "xib", "storyboard"]

        for range in pathRanges.reversed() {
            if message[range].hasPrefix(moduleNamePrefix) {
                // allow DuckDuckGo_Privacy_Browser/something…
            } else if let appUrlRange = message[range].range(of: bundleUrlPrefix) {
                // replace path to the app with just "DuckDuckGo.app"
                message.replaceSubrange(appUrlRange, with: "file:///DuckDuckGo.app/")
            } else if let appPathRange = message[range].range(of: bundlePathPrefix) {
                // replace path to the app with just "DuckDuckGo.app"
                message.replaceSubrange(appPathRange, with: "DuckDuckGo.app/")
            } else {
                let path = String(message[range])
                if allowedExtensions.contains(path.pathExtension) {
                    // drop leading path components
                    message.replaceSubrange(range, with: path.lastPathComponent)
                } else {
                    // remove file path
                    message.replaceSubrange(range, with: "<removed>")
                }
            }
        }

        // clean-up emails
        message = message.replacing(RegEx.email, with: "<removed>")

        return message
    }

    // MARK: - Mutating

    @inlinable mutating func prepend(_ string: String) {
        self = string + self
    }

    // MARK: - Prefix

    func hasOrIsPrefix(of other: String) -> Bool {
        return hasPrefix(other) || other.hasPrefix(self)
    }

}
