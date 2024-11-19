//
//  TestsURLExtension.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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

// Integration Tests helpers
extension URL {

    static let testsServer = URL(string: "http://localhost:8085/")!

    /// used for Tests Server mock HTTP requests creation (see tests-server/main.swift)
    /**
     - Parameter status: HTTP status code returned by the server, defaults to 200.
     - Parameter reason: HTTP status string, defaults to "OK".
     - Parameter data: response content data,
        by default the server will use the provided filename looking for it in the Integration Tests target resource file
        when no filename neither data are provided the response will be empty
     - Parameter headers: HTTP headers returned in the server response

     Usage:
        let url = URL.testsServer
           .appendingPathComponent("filename")  // "http://localhost:8085/filename"
           .appendingTestParameters(status: 301,
                               reason: "Moved",
                               data: Data(),
                               headers: ["Location": "/redirect-location.html"])
        Tab.setUrl(url)
     */
    func appendingTestParameters(status: Int? = nil, reason: String? = nil, data: Data? = nil, headers: [String: String]? = nil) -> URL {
        var url = self
        if let status {
            url = url.appendingParameter(name: "status", value: String(status))
        }
        if let reason {
            url = url.appendingParameter(name: "reason", value: reason)
        }
        if let headers {
            let value = URL(string: "/")!.appendingParameters(headers).query!
            url = url.appendingParameter(name: "headers", value: value)
        }
        if let data, let dataStr = String(data: data, encoding: .utf8) {
            url = url.appendingParameter(name: "data", value: dataStr)
        } else if let data {
            url = url.appendingParameter(name: "data", value: data.base64EncodedString())
        }
        return url
    }

    private func appendingParameters<QueryParams: Collection>(_ parameters: QueryParams, allowedReservedCharacters: CharacterSet? = nil) -> URL
    where QueryParams.Element == (key: String, value: String) {

        return parameters.reduce(self) { partialResult, parameter in
            partialResult.appendingParameter(
                name: parameter.key,
                value: parameter.value,
                allowedReservedCharacters: allowedReservedCharacters
            )
        }
    }

    private func appendingParameter(name: String, value: String, allowedReservedCharacters: CharacterSet? = nil) -> URL {
        let queryItem = URLQueryItem(percentEncodingName: name,
                                     value: value,
                                     withAllowedCharacters: allowedReservedCharacters)
        return self.appending(percentEncodedQueryItem: queryItem)
    }

    private func appending(percentEncodedQueryItem: URLQueryItem) -> URL {
        appending(percentEncodedQueryItems: [percentEncodedQueryItem])
    }

    private func appending(percentEncodedQueryItems: [URLQueryItem]) -> URL {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: true) else { return self }

        var existingPercentEncodedQueryItems = components.percentEncodedQueryItems ?? [URLQueryItem]()
        existingPercentEncodedQueryItems.append(contentsOf: percentEncodedQueryItems)
        components.percentEncodedQueryItems = existingPercentEncodedQueryItems

        return components.url ?? self
    }
}

fileprivate extension URLQueryItem {

    init(percentEncodingName name: String, value: String, withAllowedCharacters allowedReservedCharacters: CharacterSet? = nil) {
        let allowedCharacters: CharacterSet = {
            if let allowedReservedCharacters = allowedReservedCharacters {
                return .urlQueryParameterAllowed.union(allowedReservedCharacters)
            }
            return .urlQueryParameterAllowed
        }()

        let percentEncodedName = name.percentEncoded(withAllowedCharacters: allowedCharacters)
        let percentEncodedValue = value.percentEncoded(withAllowedCharacters: allowedCharacters)

        self.init(name: percentEncodedName, value: percentEncodedValue)
    }

}

extension StringProtocol {

    fileprivate func percentEncoded(withAllowedCharacters allowedCharacters: CharacterSet) -> String {
        if let percentEncoded = self.addingPercentEncoding(withAllowedCharacters: allowedCharacters) {
            return percentEncoded
        }
        assertionFailure("Unexpected failure")
        return components(separatedBy: allowedCharacters.inverted).joined()
    }

    var utf8data: Data {
        data(using: .utf8)!
    }
}

public extension CharacterSet {

    /**
     * As per [RFC 3986](https://www.rfc-editor.org/rfc/rfc3986#section-2.2).
     *
     * This set contains all reserved characters that are otherwise
     * included in `CharacterSet.urlQueryAllowed` but still need to be percent-escaped.
     */
    static let urlQueryReserved = CharacterSet(charactersIn: ":/?#[]@!$&'()*+,;=")

    static let urlQueryParameterAllowed = CharacterSet.urlQueryAllowed.subtracting(Self.urlQueryReserved)
    static let urlQueryStringAllowed = CharacterSet(charactersIn: "%+?").union(.urlQueryParameterAllowed)

}
