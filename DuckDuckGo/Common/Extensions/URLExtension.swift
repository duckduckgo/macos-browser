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
import BrowserServicesKit

extension URL {

    // MARK: - Local

    static var sandboxApplicationSupportURL: URL {
        let sandboxPathComponent = "Containers/\(Bundle.main.bundleIdentifier!)/Data/Library/Application Support/"
        let libraryURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        return libraryURL.appendingPathComponent(sandboxPathComponent)
    }

    static func persistenceLocation(for fileName: String) -> URL {
        let applicationSupportPath = URL.sandboxApplicationSupportURL
        return applicationSupportPath.appendingPathComponent(fileName)
    }

    // MARK: - Factory

    static func makeSearchUrl(from searchQuery: String) -> URL? {
        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedQuery.isEmpty else {
            return nil
        }

        do {
            return try Self.duckDuckGo
                .appendingParameter(name: DuckDuckGoParameters.search.rawValue, value: trimmedQuery)
        } catch let error {
            os_log("URL extension: %s", type: .error, error.localizedDescription)
            return nil
        }
    }

    static func makeURL(from addressBarString: String) -> URL? {
        let trimmed = addressBarString.trimmingWhitespaces()

        if let addressBarUrl = URL(trimmedAddressBarString: trimmed), addressBarUrl.isValid {
            return addressBarUrl
        }

        if let searchUrl = URL.makeSearchUrl(from: trimmed) {
            return searchUrl
        }

        os_log("URL extension: Making URL from %s failed", type: .error, addressBarString)
        return nil
    }

    /// URL and URLComponents can't cope with emojis and international characters so this routine does some manual processing while trying to
    /// retain the input as much as possible.
    init?(trimmedAddressBarString: String) {
        var s = trimmedAddressBarString

        // Creates URL even if user enters one slash "/" instead of two slashes "//" after the hypertext scheme component
        if let scheme = NavigationalScheme.hypertextSchemes.first(where: { s.hasPrefix($0.rawValue + ":/") }),
           !s.hasPrefix(scheme.separated()) {
            s = scheme.separated() + s.dropFirst(scheme.separated().count - 1)
        }

        if let url = URL(string: s) {
            // if URL has domain:port or user:password@domain mistakengly interpreted as a scheme
            if let urlWithScheme = URL(string: NavigationalScheme.http.separated() + s),
               urlWithScheme.port != nil || urlWithScheme.user != nil {
                // could be a local domain but user needs to use the protocol to specify that
                // make exception for "localhost"
                guard urlWithScheme.host?.contains(".") == true || urlWithScheme.host == .localhost else { return nil }
                self = urlWithScheme
                return

            } else if url.scheme != nil {
                self = url
                return

            } else if let hostname = s.split(separator: "/").first {
                guard hostname.contains(".") || String(hostname) == .localhost else {
                    // could be a local domain but user needs to use the protocol to specify that
                    return nil
                }
            } else {
                return nil
            }

            s = NavigationalScheme.http.separated() + s
        }

        self.init(punycodeEncodedString: s)
    }

    private init?(punycodeEncodedString: String) {
        var s = punycodeEncodedString
        let scheme: String

        if s.hasPrefix(URL.NavigationalScheme.http.separated()) {
            scheme = URL.NavigationalScheme.http.separated()
        } else if s.hasPrefix(URL.NavigationalScheme.https.separated()) {
            scheme = URL.NavigationalScheme.https.separated()
        } else if !s.contains(".") {
            return nil
        } else {
            scheme = URL.NavigationalScheme.http.separated()
            s = scheme + s
        }

        let urlAndQuery = s.split(separator: "?")
        guard !urlAndQuery.isEmpty, !urlAndQuery[0].contains(" ") else {
            return nil
        }

        var query = ""
        if urlAndQuery.count > 1 {
            // replace spaces with %20 in query values
            do {
                struct Throwable: Error {}
                query = try "?" + urlAndQuery[1].components(separatedBy: "&").map { component in
                    try component.components(separatedBy: "=").enumerated().map { (idx, component) -> String in
                        if idx == 0 { // name
                            // don't allow spaces in query names
                            guard !component.contains(" ") else { throw Throwable() }
                            return component
                        } else { // value
                            return component.replacingOccurrences(of: " ", with: "%20")
                        }
                    }.joined(separator: "=")
                }.joined(separator: "&")
            } catch {
                return nil
            }
        }

        let componentsWithoutQuery = urlAndQuery[0].split(separator: "/").dropFirst().map(String.init)
        guard !componentsWithoutQuery.isEmpty else {
            return nil
        }

        let host = componentsWithoutQuery[0].punycodeEncodedHostname

        let encodedPath = componentsWithoutQuery
            .dropFirst()
            .map { $0.addingPercentEncoding(withAllowedCharacters: NSCharacterSet.urlPathAllowed) ?? $0 }
            .joined(separator: "/")

        let hostPathSeparator = !encodedPath.isEmpty || urlAndQuery[0].hasSuffix("/") ? "/" : ""
        let url = scheme + host + hostPathSeparator + encodedPath + query

        self.init(string: url)
    }

    static func makeURL(fromSuggestionPhrase phrase: String) -> URL? {
        guard let url = URL(trimmedAddressBarString: phrase), url.isValid else { return nil }
        return url
    }

    static var blankPage: URL {
        return URL(string: "about:blank")!
    }

    static var homePage: URL {
        return URL(string: "about:home")!
    }

    static var welcome: URL {
        return URL(string: "about:welcome")!
    }

    static var preferences: URL {
        return URL(string: "about:preferences")!
    }

    static func preferencePane(_ pane: PreferencePaneIdentifier) -> URL {
        return Self.preferences.appendingPathComponent(pane.rawValue)
    }

    // MARK: Pixel

    static let pixelBase = ProcessInfo.processInfo.environment["PIXEL_BASE_URL", default: "https://improving.duckduckgo.com"]

    static func pixelUrl(forPixelNamed pixelName: String) -> URL {
        let urlString = "\(Self.pixelBase)/t/\(pixelName)"
        let url = URL(string: urlString)!
        // url = url.addParameter(name: \"atb\", value: statisticsStore.atbWithVariant ?? \"\")")
        // https://app.asana.com/0/1177771139624306/1199951074455863/f
        return url
    }

    // MARK: ATB

    static var devMode: String {
        #if DEBUG
        return "?test=1"
        #else
        return ""
        #endif
    }

    static let atb = "\(Self.duckDuckGo)atb.js\(devMode)"
    static let exti = "\(Self.duckDuckGo)exti/\(devMode)"

    static var initialAtb: URL {
        return URL(string: Self.atb)!
    }

    static func searchAtb(atbWithVariant: String, setAtb: String) -> URL? {
        return try? Self.initialAtb
            .appendingParameters([
                DuckDuckGoParameters.ATB.atb: atbWithVariant,
                DuckDuckGoParameters.ATB.setAtb: setAtb
            ])
    }

    static func appRetentionAtb(atbWithVariant: String, setAtb: String) -> URL? {
        return try? Self.initialAtb
            .appendingParameters([
                DuckDuckGoParameters.ATB.activityType: DuckDuckGoParameters.ATB.appUsageValue,
                DuckDuckGoParameters.ATB.atb: atbWithVariant,
                DuckDuckGoParameters.ATB.setAtb: setAtb
            ])
    }

    static func exti(forAtb atb: String) -> URL? {
        let extiUrl = URL(string: Self.exti)!
        return try? extiUrl.appendingParameter(name: DuckDuckGoParameters.ATB.atb, value: atb)
    }

    // MARK: - Components

    struct NavigationalScheme: RawRepresentable, Hashable {
        let rawValue: String

        static let separator = "://"

        static let http = NavigationalScheme(rawValue: "http")
        static let https = NavigationalScheme(rawValue: "https")
        static let file = NavigationalScheme(rawValue: "ftp")

        func separated() -> String {
            self.rawValue + Self.separator
        }

        static var hypertextSchemes: [NavigationalScheme] {
            return [.http, .https]
        }

        static var validSchemes: [NavigationalScheme] {
            return [.http, .https, .file]
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
        let hasInputScheme = input.hasOrIsPrefix(of: self.separatedScheme ?? "")
        let hasInputWww = input.drop(prefix: self.separatedScheme ?? "").hasOrIsPrefix(of: URL.HostPrefix.www.rawValue)
        let hasInputHost = (decodePunycode ? host?.idnaDecoded : host)?.hasOrIsPrefix(of: input) ?? false

        return self.toString(decodePunycode: decodePunycode,
                             dropScheme: input.isEmpty || !(hasInputScheme && !hasInputHost),
                             needsWWW: !input.drop(prefix: self.separatedScheme ?? "").isEmpty
                                && hasInputWww
                                && !hasInputHost,
                             dropTrailingSlash: !input.hasSuffix("/"))
    }

    /// Tries to use the file name part of the URL, if available, adjusting for content type, if available.
    var suggestedFilename: String? {
        let url = self

        var filename: String
        if !url.pathComponents.isEmpty,
           url.pathComponents != [ "/" ] {

            filename = url.lastPathComponent
        } else {
            filename = url.host?.dropWWW().replacingOccurrences(of: ".", with: "_") ?? ""
        }
        guard !filename.isEmpty else { return nil }

        return filename
    }

    public func isPart(ofDomain domain: String) -> Bool {
        guard let host = host else { return false }
        return host == domain || host.hasSuffix(".\(domain)")
    }

    // MARK: - Validity

    var isValid: Bool {
        guard let scheme = scheme.map(NavigationalScheme.init) else { return false }

        if NavigationalScheme.hypertextSchemes.contains(scheme) {
           return host?.isValidHost == true && user == nil
        }

        // This effectively allows file:// and External App Scheme URLs to be entered by user
        // Without this check single word entries get treated like domains
        return true
    }

    var isDataURL: Bool {
        return scheme == "data"
    }

    var isExternalSchemeLink: Bool {
        return !["https", "http", "about", "file", "blob", "data", "ftp"].contains(scheme)
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

    static var gpcLearnMore: URL {
        return URL(string: "https://help.duckduckgo.com/duckduckgo-help-pages/privacy/gpc/")!
    }

    static var privacyPolicy: URL {
        return URL(string: "https://duckduckgo.com/privacy")!
    }

    static var duckDuckGoEmail = URL(string: "https://duckduckgo.com/email-protection")!

    static var duckDuckGoMorePrivacyInfo = URL(string: "https://help.duckduckgo.com/duckduckgo-help-pages/privacy/atb/")!

    var isDuckDuckGo: Bool {
        absoluteString.starts(with: Self.duckDuckGo.absoluteString)
    }

    // swiftlint:disable unused_optional_binding
    var isDuckDuckGoSearch: Bool {
        if isDuckDuckGo, path.isEmpty || path == "/", let _ = try? getParameter(name: DuckDuckGoParameters.search.rawValue) {
            return true
        }

        return false
    }
    // swiftlint:enable unused_optional_binding

    enum DuckDuckGoParameters: String {
        case search = "q"
        case ia
        case iax

        enum ATB {
            static let atb = "atb"
            static let setAtb = "set_atb"
            static let activityType = "at"

            static let appUsageValue = "app_use"
        }
    }

    // MARK: - Search

    var searchQuery: String? {
        guard isDuckDuckGoSearch else { return nil }
        return try? getParameter(name: DuckDuckGoParameters.search.rawValue)
    }

    // MARK: - Punycode

    var punycodeDecodedString: String? {
        return self.toString(decodePunycode: true, dropScheme: false, dropTrailingSlash: false)
    }

    // MARK: - File URL

    var volume: URL? {
        try? self.resourceValues(forKeys: [.volumeURLKey]).volume
    }

    func sanitizedForQuarantine() -> URL? {
        guard !self.isFileURL,
              !["data", "blob"].contains(self.scheme),
              var components = URLComponents.init(url: self, resolvingAgainstBaseURL: false)
        else {
            return nil
        }

        components.user = nil
        components.password = nil

        return components.url
    }

    func setQuarantineAttributes(sourceURL: URL?, referrerURL: URL?) throws {
        guard self.isFileURL,
              FileManager.default.fileExists(atPath: self.path)
        else {
            throw CocoaError(CocoaError.Code.fileNoSuchFile)
        }

        let sourceURL = sourceURL?.sanitizedForQuarantine()
        let referrerURL = referrerURL?.sanitizedForQuarantine()

        if var quarantineProperties = try self.resourceValues(forKeys: [.quarantinePropertiesKey]).quarantineProperties {
            quarantineProperties[kLSQuarantineAgentBundleIdentifierKey as String] = Bundle.main.bundleIdentifier
            quarantineProperties[kLSQuarantineAgentNameKey as String] = Bundle.main.displayName

            quarantineProperties[kLSQuarantineDataURLKey as String] = sourceURL
            quarantineProperties[kLSQuarantineOriginURLKey as String] = referrerURL

            if quarantineProperties[kLSQuarantineTypeKey as String] == nil {
                quarantineProperties[kLSQuarantineTypeKey as String] = ["http", "https"].contains(sourceURL?.scheme)
                    ? kLSQuarantineTypeWebDownload
                    : kLSQuarantineTypeOtherDownload
            }

            try (self as NSURL).setResourceValue(quarantineProperties, forKey: .quarantinePropertiesKey)
        }

    }

    // MARK: - GPC

    static func gpcHeadersEnabled(config: PrivacyConfiguration) -> [String] {
        let settings = config.settings(for: .gpc)

        guard let enabledSites = settings["gpcHeaderEnabledSites"] as? [String] else {
            return []
        }

        return enabledSites
    }

    static func isGPCEnabled(url: URL,
                             config: PrivacyConfiguration = ContentBlocking.shared.privacyConfigurationManager.privacyConfig) -> Bool {
        let enabledSites = gpcHeadersEnabled(config: config)

        for gpcHost in enabledSites {
            if url.isPart(ofDomain: gpcHost) {
                // Check if url is on exception list
                // Since headers are only enabled for a small numbers of sites
                // perfrom this check here for efficency
                return config.isFeature(.gpc, enabledForDomain: url.host)
            }
        }

        return false
    }

    // MARK: - Waitlist

    static let developmentEndpoint = URL(string: "https://quackdev.duckduckgo.com/api/")!
    static let productionEndpoint = URL(string: "https://quack.duckduckgo.com/api/")!

    static func redeemMacWaitlistInviteCode(endpoint: URL = .developmentEndpoint) -> URL {
        return endpoint.appendingPathComponent("auth/invites/macosbrowser/redeem")
    }

}
