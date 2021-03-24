//
//  String+Punycode.swift
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
import Punycode

extension String {

    /// URL and URLComponents can't cope with emojis and international characters so this routine does some manual processing while trying to
    ///  retain the input as much as possible.
    var punycodedUrl: URL? {
        if let url = URL(string: self) {
            guard url.scheme != nil else {
                return (URL.NavigationalScheme.http.separated() + self).punycodedUrl
            }

            return url
        }

        if contains(" ") {
            return nil
        }

        let scheme: String
        var s = self

        if hasPrefix(URL.NavigationalScheme.http.separated()) {
            scheme = URL.NavigationalScheme.http.separated()
        } else if hasPrefix(URL.NavigationalScheme.https.separated()) {
            scheme = URL.NavigationalScheme.https.separated()
        } else if !contains(".") {
            // could be a local domain but user needs to use the protocol to specify that
            return nil
        } else {
            scheme = URL.NavigationalScheme.http.separated()
            s = scheme + s
        }

        let urlAndQuery = s.split(separator: "?")
        guard urlAndQuery.count > 0 else {
            return nil
        }

        let query = urlAndQuery.count > 1 ? "?" + urlAndQuery[1] : ""
        let componentsWithoutQuery = [String](urlAndQuery[0].split(separator: "/").map(String.init).dropFirst())
        guard componentsWithoutQuery.count > 0 else {
            return nil
        }

        let host = componentsWithoutQuery[0].punycodeEncodedHostname
        let encodedPath = componentsWithoutQuery
            .dropFirst()
            .map { $0.addingPercentEncoding(withAllowedCharacters: NSCharacterSet.urlPathAllowed) ?? $0 }
            .joined(separator: "/")

        let hostPathSeparator = !encodedPath.isEmpty || hasSuffix("/") ? "/" : ""
        let url = scheme + host + hostPathSeparator + encodedPath + query
        return URL(string: url)
    }

    public var punycodeEncodedHostname: String {
        return self.split(separator: ".")
            .map { String($0) }
            .map { $0.idnaEncoded ?? $0 }
            .joined(separator: ".")
    }
    
}
