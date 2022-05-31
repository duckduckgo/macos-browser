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

    // MARK: - URL

    var url: URL? {
        return URL(trimmedAddressBarString: self)
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
