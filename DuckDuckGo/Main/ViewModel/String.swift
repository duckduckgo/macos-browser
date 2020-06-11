//
//  String.swift
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

extension String {

    // MARK: - URL

    var isValidUrl: Bool {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return false
            //todo os og
        }
        let range = NSRange(location: 0, length: self.utf16.count)

        if let match = detector.firstMatch(in: self, options: [], range: range) {
            return match.range.length == self.utf16.count
        } else {
            return false
        }
    }

    var url: URL? {
        guard isValidUrl else { return nil }

        guard let url = URL(string: self) else { return nil }

        guard let scheme = url.scheme else {
            var string = self
            string.prepend(URL.Scheme.https.separated())
            return string.url
        }

        guard URL.Scheme(rawValue: scheme) != nil else { return nil }

        guard url.host != nil else { return nil }

        return url
    }

    // MARK: - Mutating

    @inlinable mutating func prepend(_ string: String) {
        self = string + self
    }

}
