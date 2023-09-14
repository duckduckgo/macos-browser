//
//  WebKitVersionProvider.swift
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

struct WebKitVersionProvider {

    static func getVersion() -> String? {
        guard let userAgent = WKWebView().value(forKey: "userAgent") as? String,
              let regularExpression = try? NSRegularExpression(pattern: #"AppleWebKit\s*\/\s*([\d.]+)"#, options: []),
              let match = regularExpression.firstMatch(in: userAgent, options: [], range: userAgent.fullRange),
              match.numberOfRanges >= 1 else {
            return nil
        }

        return userAgent[match.range(at: 1)].map(String.init)
    }

}
