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

    static let safari = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_6) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0.3 Safari/605.1.15"
    static let chrome = "Mozilla/5.0 (Macintosh; Intel Mac OS X 11_1_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/89.0.4389.82 Safari/537.36"

    static let `default` = UserAgent.safari

    static let domainUserAgents = [
        "mail.google.com": UserAgent.safari,
        "*.google.com": UserAgent.chrome
    ]

    static func forDomain(_ domain: String) -> String {
        if let agent = domainUserAgents[domain] ?? domainUserAgents["*." + domain] {
            return agent
        }

        let components = domain.split(separator: ".")
        guard components.count > 1 else {
            return Self.default
        }

        for i in 1..<(components.count - 1) {
            let wildcard = "*." + components[i...].joined(separator: ".")
            if let agent = domainUserAgents[wildcard] {
                return agent
            }
        }

        return Self.default
    }

}
