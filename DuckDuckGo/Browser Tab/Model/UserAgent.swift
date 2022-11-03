//
//  UserAgent.swift
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

enum UserAgent {

    static let safari = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.2 Safari/605.1.15"
    static let chrome = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.101 Safari/537.36"

    static let `default` = UserAgent.safari

    static let domainUserAgents: KeyValuePairs<RegEx, String> = [
        // fix broken spreadsheets
        regex("https://docs\\.google\\.com/spreadsheets/.*"): UserAgent.chrome
    ]

    static func `for`(_ url: URL?) -> String {
        guard let absoluteString = url?.absoluteString else {
            return Self.default
        }

        for (regex, userAgent) in domainUserAgents where absoluteString.matches(regex) {
            return userAgent
        }

        return Self.default
    }

}
