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

    // MARK: - Regular Expression

    func matches(pattern: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return false
        }
        let matches = regex.matches(in: self, options: .anchored, range: NSRange(location: 0, length: count))
        return matches.count == 1
    }

    // MARK: - URL

    var url: URL? {
        guard let url = URL(string: self) else { return nil }

        guard url.scheme != nil else {
            var string = self
            string.prepend(URL.Scheme.https.separated())
            return string.url
        }

        return url
    }

    static let localhost = "localhost"

    var isValidHost: Bool {
        return isValidHostname || isValidIpHost
    }

    var isValidHostname: Bool {
        if self == Self.localhost {
            return true
        }

        // from https://stackoverflow.com/a/25717506/73479
        let hostNameRegex = "^(((?!-)[A-Za-z0-9-]{1,63}(?<!-)\\.)+[A-Za-z0-9-]{2,63})$"
        return matches(pattern: hostNameRegex)
    }

    var isValidIpHost: Bool {
        // from https://stackoverflow.com/a/30023010/73479
        let ipRegex = "^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"
        return matches(pattern: ipRegex)
    }

    func encodingWebSpaces() -> String {
        return replacingOccurrences(of: "+", with: "%20")
    }

    // MARK: - Mutating

    @inlinable mutating func prepend(_ string: String) {
        self = string + self
    }

}
