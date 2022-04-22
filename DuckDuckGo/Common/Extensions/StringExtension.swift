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

import Foundation
import os.log

typealias RegEx = NSRegularExpression

func regex(_ pattern: String, _ options: NSRegularExpression.Options = []) -> NSRegularExpression {
    // swiftlint:disable force_try
    return try! NSRegularExpression(pattern: pattern, options: options)
    // swiftlint:enable force_try
}

private extension RegEx {
    // from https://stackoverflow.com/a/25717506/73479
    static let hostName = regex("^(((?!-)[A-Za-z0-9-]{1,63}(?<!-)\\.)*[A-Za-z0-9-]{2,63})$", .caseInsensitive)
    // from https://stackoverflow.com/a/30023010/73479
    static let ipAddress = regex("^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$",
                                 .caseInsensitive)
}

extension String {

    // MARK: - General

    func trimmingWhitespaces() -> String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func nsRange(from range: Range<String.Index>? = nil) -> NSRange {
        if let range = range {
            return NSRange(location: self[..<range.lowerBound].utf16.count,
                           length: self[range].utf16.count)
        } else {
            return NSRange(location: 0, length: utf16.count)
        }
    }

    func truncated(length: Int, trailing: String = "…") -> String {
      return (self.count > length) ? self.prefix(length) + trailing : self
    }

    subscript (_ range: NSRange) -> Self {
        .init(self[utf16.index(startIndex, offsetBy: range.lowerBound) ..< utf16.index(startIndex, offsetBy: range.upperBound)])
    }

    // MARK: - Regular Expression

    func matches(_ regex: NSRegularExpression) -> Bool {
        let matches = regex.matches(in: self, options: .anchored, range: NSRange(location: 0, length: self.utf16.count))
        return matches.count == 1
    }

    // MARK: - URL

    var url: URL? {
        return URL(trimmedAddressBarString: self)
    }

    static let localhost = "localhost"

    var isValidHost: Bool {
        return isValidHostname || isValidIpHost
    }

    var isValidHostname: Bool {
        if self == Self.localhost {
            return true
        }
        return matches(.hostName)
    }

    var isValidIpHost: Bool {
        return matches(.ipAddress)
    }

    func dropSubdomain() -> String? {
        let parts = components(separatedBy: ".")
        guard parts.count > 1 else { return nil }
        return parts.dropFirst().joined(separator: ".")
    }

    func dropWWW() -> String {
        self.drop(prefix: URL.HostPrefix.www.separated())
    }

    static func uniqueFilename(for fileType: UTType? = nil) -> String {
        let fileName = UUID().uuidString

        if let ext = fileType?.fileExtension {
            return fileName.appending("." + ext)
        }

        return fileName
    }

    // MARK: - Mutating

    @inlinable mutating func prepend(_ string: String) {
        self = string + self
    }

    // MARK: - Prefix

    func hasOrIsPrefix(of other: String) -> Bool {
        return hasPrefix(other) || other.hasPrefix(self)
    }

    func drop(prefix: String) -> String {
        return hasPrefix(prefix) ? String(dropFirst(prefix.count)) : self
    }

    // MARK: - Suffix

    func drop(suffix: String) -> String {
        return hasSuffix(suffix) ? String(dropLast(suffix.count)) : self
    }

}
