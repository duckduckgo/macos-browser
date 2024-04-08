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
        "}": "&#125;"
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

    func appendingPathComponent(_ component: String) -> String {
        (self as NSString).appendingPathComponent(component)
    }

    func appendingPathExtension(_ pathExtension: String?) -> String {
        guard let pathExtension, !pathExtension.isEmpty else { return self }
        return self + "." + pathExtension
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
