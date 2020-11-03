//
//  URLExtension.swift
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

extension URL {

    // MARK: - Factory

    static func makeSearchUrl(from searchQuery: String) -> URL? {
        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            var searchUrl = Self.duckDuckGo
            searchUrl = try searchUrl.addParameter(name: DuckDuckGoParameters.search.rawValue, value: trimmedQuery)
            return searchUrl
        } catch let error {
            os_log("URL extension: %s", type: .error, error.localizedDescription)
            return nil
        }
    }

    static func makeURL(from addressBarString: String) -> URL? {
        if let addressBarUrl = addressBarString.url, addressBarUrl.isValid {
            return addressBarUrl
        }

        if let searchUrl = URL.makeSearchUrl(from: addressBarString) {
            return searchUrl
        }

        os_log("URL extension: Making URL from %s failed", type: .error, addressBarString)
        return nil
    }

    static var emptyPage: URL {
        return URL(string: "about:blank")!
    }

    // MARK: - Parameters

    enum ParameterError: Error {
        case parsingFailed
        case encodingFailed
        case creatingFailed
    }

    func addParameter(name: String, value: String) throws -> URL {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else { throw ParameterError.parsingFailed }
        var queryItems = components.queryItems ?? [URLQueryItem]()
        let newQueryItem = URLQueryItem(name: name, value: value)
        queryItems.append(newQueryItem)
        components.queryItems = queryItems
        guard let encodedQuery = components.percentEncodedQuery else { throw ParameterError.encodingFailed }
        components.percentEncodedQuery = encodedQuery.encodingWebSpaces()
        guard let newUrl = components.url else { throw ParameterError.creatingFailed }
        return newUrl
    }

    func getParameter(name: String) throws -> String? {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else { throw ParameterError.parsingFailed }
        guard let encodedQuery = components.percentEncodedQuery else { throw ParameterError.encodingFailed }
        components.percentEncodedQuery = encodedQuery.encodingWebSpaces()
        let queryItem = components.queryItems?.first(where: { (queryItem) -> Bool in
            queryItem.name == name
        })
        return queryItem?.value
    }

    // MARK: - Components

    enum Scheme: String, CaseIterable {
        case http
        case https

        func separated() -> String {
            self.rawValue + "://"
        }
    }

    enum HostPrefix: String {
        case www

        func separated() -> String {
            self.rawValue + "."
        }
    }

    // MARK: - Validity

    var isValid: Bool {
        guard let scheme = scheme,
              URL.Scheme(rawValue: scheme) != nil,
              let host = host, host.isValidHost,
              user == nil else {
            return false
        }

        return true
    }

    // MARK: - DuckDuckGo

    static var duckDuckGo: URL {
        let duckDuckGoUrlString = "https://duckduckgo.com/"
        return URL(string: duckDuckGoUrlString)!
    }

    static var duckDuckGoAutocomplete: URL {
        duckDuckGo.appendingPathComponent("ac/")
    }

    var isDuckDuckGo: Bool {
        absoluteString.starts(with: Self.duckDuckGo.absoluteString)
    }

    // swiftlint:disable unused_optional_binding
    var isDuckDuckGoSearch: Bool {
        if isDuckDuckGo, let _ = try? getParameter(name: DuckDuckGoParameters.search.rawValue) {
            return true
        }

        return false
    }
    // swiftlint:enable unused_optional_binding

    enum DuckDuckGoParameters: String {
        case search = "q"
    }

    // MARK: - Search

    var searchQuery: String? {
        guard isDuckDuckGo else { return nil }
        return try? getParameter(name: DuckDuckGoParameters.search.rawValue)
    }

    // MARK: - Local

    static var applicationSupport: URL {
        guard let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Database: Failed to get Application Support file URL")
        }
        return url
    }

    // MARK: - HTTPS

    enum URLProtocol: String {
        case http
        case https

        public var scheme: String {
            return "\(rawValue)://"
        }
    }

    func toHttps() -> URL? {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else { return self }
        guard components.scheme == URLProtocol.http.rawValue else { return self }
        components.scheme = URLProtocol.https.rawValue
        return components.url
    }

}
