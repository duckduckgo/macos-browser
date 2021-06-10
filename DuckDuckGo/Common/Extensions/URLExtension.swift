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
        let trimmed = addressBarString.trimmingWhitespaces()

        if let addressBarUrl = trimmed.punycodedUrl, addressBarUrl.isValid {
            return addressBarUrl
        }

        if let searchUrl = URL.makeSearchUrl(from: trimmed) {
            return searchUrl
        }

        os_log("URL extension: Making URL from %s failed", type: .error, addressBarString)
        return nil
    }

    static func makeURL(fromSuggestionPhrase phrase: String) -> URL? {
        guard let url = phrase.punycodedUrl, url.isValid else { return nil }
        return url
    }

    static var emptyPage: URL {
        return URL(string: "about:blank")!
    }

    static let pixelBase = ProcessInfo.processInfo.environment["PIXEL_BASE_URL", default: "https://improving.duckduckgo.com"]

    static func pixelUrl(forPixelNamed pixelName: String) -> URL {
        let urlString = "\(Self.pixelBase)/t/\(pixelName)"
        let url = URL(string: urlString)!
        // url = url.addParameter(name: \"atb\", value: statisticsStore.atbWithVariant ?? \"\")")
        // https://app.asana.com/0/1177771139624306/1199951074455863/f
        return url
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
        components.percentEncodedQuery = encodedQuery.encodingPluses()
        guard let newUrl = components.url else { throw ParameterError.creatingFailed }
        return newUrl
    }

    func getParameter(name: String) throws -> String? {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else { throw ParameterError.parsingFailed }
        guard let encodedQuery = components.percentEncodedQuery else { throw ParameterError.encodingFailed }
        components.percentEncodedQuery = encodedQuery.encodingPlusesAsSpaces()
        let queryItem = components.queryItems?.first(where: { (queryItem) -> Bool in
            queryItem.name == name
        })
        return queryItem?.value
    }

    // MARK: - Components

    enum NavigationalScheme: String, CaseIterable {
        static let separator = "://"

        case http
        case https

        func separated() -> String {
            self.rawValue + Self.separator
        }
    }

    enum HostPrefix: String {
        case www

        func separated() -> String {
            self.rawValue + "."
        }
    }

    var separatedScheme: String? {
        self.scheme.map { $0 + NavigationalScheme.separator }
    }

    func toString(decodePunycode: Bool,
                  dropScheme: Bool,
                  needsWWW: Bool? = nil,
                  dropTrailingSlash: Bool) -> String {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: true),
              var string = components.string
        else {
            return absoluteString
        }

        if var host = components.host,
           let hostRange = components.rangeOfHost {

            switch (needsWWW, host.hasPrefix(HostPrefix.www.separated())) {
            case (.some(true), true),
                 (.some(false), false),
                 (.none, _):
                break
            case (.some(false), true):
                host = host.drop(prefix: HostPrefix.www.separated())
            case (.some(true), false):
                host = HostPrefix.www.separated() + host
            }

            if decodePunycode,
               let decodedHost = host.idnaDecoded {
                host = decodedHost
            }

            string.replaceSubrange(hostRange, with: host)
        }

        if dropScheme,
           let schemeRange = components.rangeOfScheme {
            string.replaceSubrange(schemeRange, with: "")
            if string.hasPrefix(URL.NavigationalScheme.separator) {
                string = string.drop(prefix: URL.NavigationalScheme.separator)
            }
        }

        if dropTrailingSlash,
           string.hasSuffix("/") {
            string = String(string.dropLast(1))
        }

        return string
    }

    func toString(forUserInput input: String, decodePunycode: Bool = true) -> String {
        self.toString(decodePunycode: decodePunycode,
                      dropScheme: input.isEmpty
                        || !input.hasOrIsPrefix(of: self.separatedScheme ?? ""),
                      needsWWW: !input.drop(prefix: self.separatedScheme ?? "").isEmpty
                        && input.drop(prefix: self.separatedScheme ?? "").hasOrIsPrefix(of: URL.HostPrefix.www.rawValue),
                      dropTrailingSlash: false)
    }

    // MARK: - Validity

    var isValid: Bool {
        guard let scheme = scheme else { return false }

        if URL.NavigationalScheme(rawValue: scheme) != nil,
           let host = host, host.isValidHost,
           user == nil { return true }

        // This effectively allows external URLs to be entered by the user.
        // Without this check single word entries get treated like domains.
        return URL.NavigationalScheme(rawValue: scheme) == nil
    }

    // MARK: - DuckDuckGo

    static var duckDuckGo: URL {
        let duckDuckGoUrlString = "https://duckduckgo.com/"
        return URL(string: duckDuckGoUrlString)!
    }

    static var duckDuckGoAutocomplete: URL {
        duckDuckGo.appendingPathComponent("ac/")
    }

    static var aboutDuckDuckGo: URL {
        return URL(string: "https://duckduckgo.com/about")!
    }

    static var duckDuckGoEmail = URL(string: "https://quack.duckduckgo.com/email/dashboard")!

    static var duckDuckGoMorePrivacyInfo = URL(string: "https://help.duckduckgo.com/duckduckgo-help-pages/privacy/atb/")!

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

    // MARK: - Feedback

#if FEEDBACK

    static var feedback: URL {
        return URL(string: "https://form.asana.com/?k=HzdxNoIgDZUBf4w0_cafIQ&d=137249556945")!
    }

#endif

    // MARK: - HTTPS

    func toHttps() -> URL? {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else { return self }
        guard components.scheme == NavigationalScheme.http.rawValue else { return self }
        components.scheme = NavigationalScheme.https.rawValue
        return components.url
    }

    // MARK: - Punycode

    var punycodeDecodedString: String? {
        return self.toString(decodePunycode: true, dropScheme: false, dropTrailingSlash: false)
    }

    // MARK: - File URL

    var volume: URL? {
        try? self.resourceValues(forKeys: [.volumeURLKey]).volume
    }

}
