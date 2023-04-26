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

import Common
import Foundation
import BrowserServicesKit

extension URL.NavigationalScheme {

    static var duckPlayer: URL.NavigationalScheme { URL.NavigationalScheme(rawValue: DuckPlayer.duckPlayerScheme) }

    static var validSchemes: [URL.NavigationalScheme] {
        return [.http, .https, .file]
    }

    static var bookmarkableSchemes: [URL.NavigationalScheme] {
        return [.http, .https, .file, .data]
    }

    static var shareableSchemes: [URL.NavigationalScheme] {
        return [.http, .https, .file, .data]
    }

}

extension URL {

    // MARK: - Local

    /**
     * Returns a URL pointing to `${HOME}/Library`, regardless of whether the app is sandboxed or not.
     */
    static var nonSandboxLibraryDirectoryURL: URL {
        guard NSApp.isSandboxed else {
            return FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        }
        return FileManager.default.homeDirectoryForCurrentUser.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    /**
     * Returns a URL pointing to `${HOME}/Library/Application Support`, regardless of whether the app is sandboxed or not.
     */
    static var nonSandboxApplicationSupportDirectoryURL: URL {
        guard NSApp.isSandboxed else {
            return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        }
        return nonSandboxLibraryDirectoryURL.appendingPathComponent("Application Support")
    }

    static var sandboxApplicationSupportURL: URL {
        if NSApp.isSandboxed {
            return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        }
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

        return Self.duckDuckGo.appendingParameter(name: DuckDuckGoParameters.search.rawValue, value: trimmedQuery)
    }

    static func makeURL(from addressBarString: String) -> URL? {
        let trimmed = addressBarString.trimmingWhitespace()

        if let addressBarUrl = URL(trimmedAddressBarString: trimmed), addressBarUrl.isValid {
            return addressBarUrl
        }

        if let searchUrl = URL.makeSearchUrl(from: trimmed) {
            return searchUrl
        }

        os_log("URL extension: Making URL from %s failed", type: .error, addressBarString)
        return nil
    }

    static func makeURL(fromSuggestionPhrase phrase: String) -> URL? {
        guard let url = URL(trimmedAddressBarString: phrase),
              let scheme = url.scheme.map(NavigationalScheme.init),
              NavigationalScheme.hypertextSchemes.contains(scheme),
              url.isValid else {
            return nil
        }

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

    var isHypertextURL: Bool {
        guard let scheme = self.scheme.map(NavigationalScheme.init(rawValue:)) else { return false }
        return NavigationalScheme.validSchemes.contains(scheme)
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

    static func searchAtb(atbWithVariant: String, setAtb: String, isSignedIntoEmailProtection: Bool) -> URL {
        return Self.initialAtb
            .appendingParameters([
                DuckDuckGoParameters.ATB.atb: atbWithVariant,
                DuckDuckGoParameters.ATB.setAtb: setAtb,
                DuckDuckGoParameters.ATB.email: isSignedIntoEmailProtection ? "1" : "0"
            ])
    }

    static func appRetentionAtb(atbWithVariant: String, setAtb: String) -> URL {
        return Self.initialAtb
            .appendingParameters([
                DuckDuckGoParameters.ATB.activityType: DuckDuckGoParameters.ATB.appUsageValue,
                DuckDuckGoParameters.ATB.atb: atbWithVariant,
                DuckDuckGoParameters.ATB.setAtb: setAtb
            ])
    }

    static func exti(forAtb atb: String) -> URL {
        let extiUrl = URL(string: Self.exti)!
        return extiUrl.appendingParameter(name: DuckDuckGoParameters.ATB.atb, value: atb)
    }

    // MARK: - Components

    enum HostPrefix: String {
        case www

        func separated() -> String {
            self.rawValue + "."
        }
    }

    var navigationalScheme: NavigationalScheme? {
        self.scheme.map(NavigationalScheme.init(rawValue:))
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
                host = host.dropping(prefix: HostPrefix.www.separated())
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
                string = string.dropping(prefix: URL.NavigationalScheme.separator)
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
        let hasInputWww = input.dropping(prefix: self.separatedScheme ?? "").hasOrIsPrefix(of: URL.HostPrefix.www.rawValue)
        let hasInputHost = (decodePunycode ? host?.idnaDecoded : host)?.hasOrIsPrefix(of: input) ?? false

        return self.toString(decodePunycode: decodePunycode,
                             dropScheme: input.isEmpty || !(hasInputScheme && !hasInputHost),
                             needsWWW: !input.dropping(prefix: self.separatedScheme ?? "").isEmpty
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
            filename = url.host?.droppingWwwPrefix().replacingOccurrences(of: ".", with: "_") ?? ""
        }
        guard !filename.isEmpty else { return nil }

        return filename
    }

    // MARK: - Validity

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

    static var webTrackingProtection: URL {
        return URL(string: "https://help.duckduckgo.com/duckduckgo-help-pages/privacy/web-tracking-protections/")!
    }

    static var cookieConsentPopUpManagement: URL {
        return URL(string: "https://help.duckduckgo.com/duckduckgo-help-pages/privacy/web-tracking-protections/#cookie-consent-pop-up-management")!
    }

    static var gpcLearnMore: URL {
        return URL(string: "https://help.duckduckgo.com/duckduckgo-help-pages/privacy/gpc/")!
    }

    static var theFireButton: URL {
        return URL(string: "https://help.duckduckgo.com/duckduckgo-help-pages/privacy/web-tracking-protections/#the-fire-button")!
    }

    static var privacyPolicy: URL {
        return URL(string: "https://duckduckgo.com/privacy")!
    }

    static var duckDuckGoEmail = URL(string: "https://duckduckgo.com/email-protection")!

    static var duckDuckGoMorePrivacyInfo = URL(string: "https://help.duckduckgo.com/duckduckgo-help-pages/privacy/atb/")!

    var isDuckDuckGo: Bool {
        absoluteString.starts(with: Self.duckDuckGo.absoluteString)
    }

    var isDuckDuckGoSearch: Bool {
        if isDuckDuckGo, path.isEmpty || path == "/", getParameter(named: DuckDuckGoParameters.search.rawValue) != nil {
            return true
        }

        return false
    }

    enum DuckDuckGoParameters: String {
        case search = "q"
        case ia
        case iax

        enum ATB {
            static let atb = "atb"
            static let setAtb = "set_atb"
            static let activityType = "at"
            static let email = "email"

            static let appUsageValue = "app_use"
        }
    }

    // MARK: - Search

    var searchQuery: String? {
        guard isDuckDuckGoSearch else { return nil }
        return getParameter(named: DuckDuckGoParameters.search.rawValue)
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
}
