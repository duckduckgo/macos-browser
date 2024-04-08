//
//  PixelKit.swift
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
import os.log // swiftlint:disable:this enforce_os_log_wrapper

public final class PixelKit {
    /// `true` if a request is fired, `false` otherwise
    public typealias CompletionBlock = (Bool, Error?) -> Void

    /// The frequency with which a pixel is sent to our endpoint.
    public enum Frequency {
        /// The default frequency for pixels. This fires pixels with the event names as-is.
        case standard

        /// Used in Pixel.fire(...) as unique but without the `_u` requirement in the name
        case legacyInitial

        /// Sent only once ever. The timestamp for this pixel is stored. 
        /// Note: This is the only pixel that MUST end with `_u`, Name for pixels of this type must end with if it doesn't an assertion is fired.
        case unique

        /// Sent once per day. The last timestamp for this pixel is stored and compared to the current date. Pixels of this type will have `_d` appended to their name.
        case daily

        /// Sent once per day with a `_d` suffix, in addition to every time it is called with a `_c` suffix.
        /// This means a pixel will get sent twice the first time it is called per-day, and subsequent calls that day will only send the `_c` variant.
        /// This is useful in situations where pixels receive spikes in volume, as the daily pixel can be used to determine how many users are actually affected.
        case dailyAndCount

        fileprivate var description: String {
            switch self {
            case .standard:
                "Standard"
            case .legacyInitial:
                "Legacy Initial"
            case .unique:
                "Unique"
            case .daily:
                "Daily"
            case .dailyAndCount:
                "Daily and Count"
            }
        }
    }

    public enum Header {
        public static let acceptEncoding = "Accept-Encoding"
        public static let acceptLanguage = "Accept-Language"
        public static let userAgent = "User-Agent"
        public static let ifNoneMatch = "If-None-Match"
        public static let moreInfo = "X-DuckDuckGo-MoreInfo"
        public static let client = "X-DuckDuckGo-Client"
    }

    /// A closure typealias to request sending pixels through the network.
    public typealias FireRequest = (
        _ pixelName: String,
        _ headers: [String: String],
        _ parameters: [String: String],
        _ allowedQueryReservedCharacters: CharacterSet?,
        _ callBackOnMainThread: Bool,
        _ onComplete: @escaping CompletionBlock) -> Void

    public typealias Event = PixelKitEvent
    public static let duckDuckGoMorePrivacyInfo = URL(string: "https://help.duckduckgo.com/duckduckgo-help-pages/privacy/atb/")!
    private let defaults: UserDefaults

    private let logger = Logger(subsystem: "com.duckduckgo.PixelKit", category: "PixelKit")

    private static let defaultDailyPixelCalendar: Calendar = {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private var dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = defaultDailyPixelCalendar
        dateFormatter.timeZone = defaultDailyPixelCalendar.timeZone
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter
    }()

    private let dateGenerator: () -> Date

    public static var shared: PixelKit?
    private let appVersion: String
    private let defaultHeaders: [String: String]
    private let fireRequest: FireRequest

    /// Sets up PixelKit for the entire app.
    ///
    /// - Parameters:
    /// - `dryRun`: if `true`, simulate requests and "send" them at an accelerated rate (once every 2 minutes instead of once a day)
    /// - `source`: if set, adds a `pixelSource` parameter to the pixel call; this can be used to specify which target is sending the pixel
    /// - `fireRequest`: this is not triggered when `dryRun` is `true`
    public static func setUp(dryRun: Bool = false,
                             appVersion: String,
                             source: String? = nil,
                             defaultHeaders: [String: String],
                             defaults: UserDefaults,
                             fireRequest: @escaping FireRequest) {
        shared = PixelKit(dryRun: dryRun,
                          appVersion: appVersion,
                          source: source,
                          defaultHeaders: defaultHeaders,
                          defaults: defaults,
                          fireRequest: fireRequest)
    }

    public static func tearDown() {
        shared = nil
    }

    private var dryRun: Bool
    private let source: String?
    private let pixelCalendar: Calendar

    public init(dryRun: Bool,
                appVersion: String,
                source: String? = nil,
                defaultHeaders: [String: String],
                dailyPixelCalendar: Calendar? = nil,
                dateGenerator: @escaping () -> Date = Date.init,
                defaults: UserDefaults,
                fireRequest: @escaping FireRequest) {

        self.dryRun = dryRun
        self.appVersion = appVersion
        self.source = source
        self.defaultHeaders = defaultHeaders
        self.pixelCalendar = dailyPixelCalendar ?? Self.defaultDailyPixelCalendar
        self.dateGenerator = dateGenerator
        self.defaults = defaults
        self.fireRequest = fireRequest

        logger.debug("""
        PixelKit initialised:
                      dryRun: \(self.dryRun)
                  appVersion: \(self.appVersion)
                      source: \(self.source ?? "-")
              defaultHeaders: \(self.defaultHeaders)
               pixelCalendar: \(self.pixelCalendar)
        """)
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    private func fire(pixelNamed pixelName: String,
                      frequency: Frequency,
                      withHeaders headers: [String: String]?,
                      withAdditionalParameters params: [String: String]?,
                      withError error: Error?,
                      allowedQueryReservedCharacters: CharacterSet?,
                      includeAppVersionParameter: Bool,
                      onComplete: @escaping CompletionBlock) {

        var newParams = params ?? [:]
        if includeAppVersionParameter { newParams[Parameters.appVersion] = appVersion }
        if let source { newParams[Parameters.pixelSource] = source }
        if let error { newParams.appendErrorPixelParams(error: error) }

        #if DEBUG
            newParams[Parameters.test] = Values.test
        #endif

        var headers = headers ?? defaultHeaders
        headers[Header.moreInfo] = "See " + Self.duckDuckGoMorePrivacyInfo.absoluteString
        headers[Header.client] = "macOS"

        switch frequency {
        case .standard:
            reportErrorIf(pixel: pixelName, endsWith: "_u")
            reportErrorIf(pixel: pixelName, endsWith: "_d")
            fireRequestWrapper(pixelName, headers, newParams, allowedQueryReservedCharacters, true, onComplete, frequency)
        case .legacyInitial:
            reportErrorIf(pixel: pixelName, endsWith: "_u")
            reportErrorIf(pixel: pixelName, endsWith: "_d")
            if !pixelHasBeenFiredEver(pixelName) {
                fireRequestWrapper(pixelName, headers, newParams, allowedQueryReservedCharacters, true, onComplete, frequency)
                updatePixelLastFireDate(pixelName: pixelName)
            } else {
                printDebugInfo(pixelName: pixelName, frequency: frequency, parameters: newParams, skipped: true)
            }
        case .unique:
            reportErrorIf(pixel: pixelName, endsWith: "_d")
            guard pixelName.hasSuffix("_u") else {
                assertionFailure("Unique pixel: must end with _u")
                return
            }
            if !pixelHasBeenFiredEver(pixelName) {
                fireRequestWrapper(pixelName, headers, newParams, allowedQueryReservedCharacters, true, onComplete, frequency)
                updatePixelLastFireDate(pixelName: pixelName)
            } else {
                printDebugInfo(pixelName: pixelName, frequency: frequency, parameters: newParams, skipped: true)
            }
        case .daily:
            reportErrorIf(pixel: pixelName, endsWith: "_u")
            reportErrorIf(pixel: pixelName, endsWith: "_d") // Because is added automatically
            if !pixelHasBeenFiredToday(pixelName) {
                fireRequestWrapper(pixelName + "_d", headers, newParams, allowedQueryReservedCharacters, true, onComplete, frequency)
                updatePixelLastFireDate(pixelName: pixelName)
            } else {
                printDebugInfo(pixelName: pixelName + "_d", frequency: frequency, parameters: newParams, skipped: true)
            }
        case .dailyAndCount:
            reportErrorIf(pixel: pixelName, endsWith: "_u")
            reportErrorIf(pixel: pixelName, endsWith: "_d") // Because is added automatically
            reportErrorIf(pixel: pixelName, endsWith: "_c") // Because is added automatically
            if !pixelHasBeenFiredToday(pixelName) {
                fireRequestWrapper(pixelName + "_d", headers, newParams, allowedQueryReservedCharacters, true, onComplete, frequency)
                updatePixelLastFireDate(pixelName: pixelName)
            } else {
                printDebugInfo(pixelName: pixelName + "_d", frequency: frequency, parameters: newParams, skipped: true)
            }

            fireRequestWrapper(pixelName + "_c", headers, newParams, allowedQueryReservedCharacters, true, onComplete, frequency)
        }
    }

    /// If the pixel name ends with the forbiddenString then an error is logged or an assertion failure is fired in debug
    func reportErrorIf(pixel: String, endsWith forbiddenString: String) {
        if pixel.hasSuffix(forbiddenString) {
            logger.error("Pixel \(pixel) must not end with \(forbiddenString)")
            assertionFailure("Pixel \(pixel) must not end with \(forbiddenString)")
        }
    }

    private func printDebugInfo(pixelName: String, frequency: Frequency, parameters: [String: String], skipped: Bool = false) {
        let params = parameters.filter { key, _ in !["test"].contains(key) }
        logger.debug("👾[\(frequency.description)-\(skipped ? "Skipped" : "Fired")] \(pixelName) \(params)")
    }

    private func fireRequestWrapper(
        _ pixelName: String,
        _ headers: [String: String],
        _ parameters: [String: String],
        _ allowedQueryReservedCharacters: CharacterSet?,
        _ callBackOnMainThread: Bool,
        _ onComplete: @escaping CompletionBlock,
        _ frequency: Frequency) {
        guard !dryRun else {
            printDebugInfo(pixelName: pixelName, frequency: frequency, parameters: parameters, skipped: false)
            // simulate server response time for Dry Run mode
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                onComplete(true, nil)
            }
            return
        }
        fireRequest(pixelName, headers, parameters, allowedQueryReservedCharacters, callBackOnMainThread, onComplete)
    }

    private func prefixedName(for event: Event) -> String {
        if event.name.hasPrefix("m_mac_") {
            return event.name
        }

        if let debugEvent = event as? DebugEvent {
            return "m_mac_debug_\(debugEvent.name)"
        } else {
            return "m_mac_\(event.name)"
        }
    }

    public func fire(_ event: Event,
                     frequency: Frequency = .standard,
                     withHeaders headers: [String: String]? = nil,
                     withAdditionalParameters params: [String: String]? = nil,
                     withError error: Error? = nil,
                     allowedQueryReservedCharacters: CharacterSet? = nil,
                     includeAppVersionParameter: Bool = true,
                     onComplete: @escaping CompletionBlock = { _, _ in }) {

        let pixelName = prefixedName(for: event)

        if !dryRun {
            if frequency == .daily, pixelHasBeenFiredToday(pixelName) {
                onComplete(false, nil)
                return
            } else if frequency == .unique, pixelHasBeenFiredEver(pixelName) {
                onComplete(false, nil)
                return
            }
        }

        let newParams: [String: String]?
        switch (event.parameters, params) {
        case (.some(let parameters), .none):
            newParams = parameters
        case (.none, .some(let parameters)):
            newParams = parameters
        case (.some(let params1), .some(let params2)):
            newParams = params1.merging(params2) { $1 }
        case (.none, .none):
            newParams = nil
        }

        let newError: Error?

        if let event = event as? PixelKitEventV2 {
            // For v2 events we only consider the error specified in the event
            // and purposedly ignore the parameter in this call.
            // This is to encourage moving the error over to the protocol error
            // instead of still relying on the parameter of this call.
            newError = event.error
        } else {
            newError = error
        }

        fire(pixelNamed: pixelName,
             frequency: frequency,
             withHeaders: headers,
             withAdditionalParameters: newParams,
             withError: newError,
             allowedQueryReservedCharacters: allowedQueryReservedCharacters,
             includeAppVersionParameter: includeAppVersionParameter,
             onComplete: onComplete)
    }

    public static func fire(_ event: Event,
                            frequency: Frequency = .standard,
                            withHeaders headers: [String: String] = [:],
                            withAdditionalParameters parameters: [String: String]? = nil,
                            withError error: Error? = nil,
                            allowedQueryReservedCharacters: CharacterSet? = nil,
                            includeAppVersionParameter: Bool = true,
                            onComplete: @escaping CompletionBlock = { _, _ in }) {

        Self.shared?.fire(event,
                          frequency: frequency,
                          withHeaders: headers,
                          withAdditionalParameters: parameters,
                          withError: error,
                          allowedQueryReservedCharacters: allowedQueryReservedCharacters,
                          includeAppVersionParameter: includeAppVersionParameter,
                          onComplete: onComplete)
    }

    private func dateString(for date: Date?) -> String? {
        guard let date else { return nil }
        return dateFormatter.string(from: date)
    }

    public static func dateString(for date: Date?) -> String {
        Self.shared?.dateString(for: date) ?? ""
    }

    public static func pixelLastFireDate(event: Event) -> Date? {
        Self.shared?.pixelLastFireDate(event: event)
    }

    public func pixelLastFireDate(pixelName: String) -> Date? {
        var date = defaults.object(forKey: userDefaultsKeyName(forPixelName: pixelName)) as? Date
        if date == nil {
            date = defaults.object(forKey: legacyUserDefaultsKeyName(forPixelName: pixelName)) as? Date
        }
        return date
    }

    public func pixelLastFireDate(event: Event) -> Date? {
        pixelLastFireDate(pixelName: prefixedName(for: event))
    }

    private func updatePixelLastFireDate(pixelName: String) {
        defaults.set(dateGenerator(), forKey: userDefaultsKeyName(forPixelName: pixelName))
    }

    private func pixelHasBeenFiredToday(_ name: String) -> Bool {
        guard !dryRun else {
            if let lastFireDate = pixelLastFireDate(pixelName: name),
               let twoMinsAgo = pixelCalendar.date(byAdding: .minute, value: -2, to: dateGenerator()) {
                return lastFireDate >= twoMinsAgo
            }

            return false
        }

        if let lastFireDate = pixelLastFireDate(pixelName: name) {
            return pixelCalendar.isDate(dateGenerator(), inSameDayAs: lastFireDate)
        }

        return false
    }

    private func pixelHasBeenFiredEver(_ name: String) -> Bool {
        pixelLastFireDate(pixelName: name) != nil
    }

    public static func clearFrequencyHistoryFor(pixel: PixelKitEventV2) {
        guard let name = Self.shared?.userDefaultsKeyName(forPixelName: pixel.name) else {
            return
        }
        Self.shared?.defaults.removeObject(forKey: name)
    }

    public static func clearFrequencyHistoryForAllPixels() {
        guard let userDefaults = Self.shared?.defaults else { return }
        for (key, _) in userDefaults.dictionaryRepresentation() {
            if key.hasPrefix(storageKeyPrefixLegacy) || key.hasPrefix(storageKeyPrefix) {
                userDefaults.removeObject(forKey: key)
                PixelKit.shared?.logger.debug("🚮 Removing from storage \(key)")
            }
        }
    }

    static let storageKeyPrefixLegacy = "com.duckduckgo.network-protection.pixel."
    static let storageKeyPrefix = "com.duckduckgo.network-protection.pixel."

    /// Initially PixelKit was configured only for serving netP so these very specific keys were used, now PixelKit serves the entire app so we need to move away from them.
    /// NOTE: I would remove this 6 months after release
    private func legacyUserDefaultsKeyName(forPixelName pixelName: String) -> String {
        dryRun
        ? "\(Self.storageKeyPrefixLegacy)\(pixelName).dry-run"
        : "\(Self.storageKeyPrefixLegacy)\(pixelName)"
    }

    private func userDefaultsKeyName(forPixelName pixelName: String) -> String {
        return "\(Self.storageKeyPrefix)\(pixelName)\( dryRun ? ".dry-run" : "" )"
    }
}

extension Dictionary where Key == String, Value == String {

    mutating func appendErrorPixelParams(error: Error) {
        let nsError = error as NSError

        self[PixelKit.Parameters.errorCode] = "\(nsError.code)"
        self[PixelKit.Parameters.errorDomain] = nsError.domain

        if let error = error as? PixelKitEventErrorDetails,
           let underlyingError = error.underlyingError {

            let underlyingNSError = underlyingError as NSError
            self[PixelKit.Parameters.underlyingErrorCode] = "\(underlyingNSError.code)"
            self[PixelKit.Parameters.underlyingErrorDomain] = underlyingNSError.domain
        } else if let underlyingError = nsError.userInfo["NSUnderlyingError"] as? NSError {
            self[PixelKit.Parameters.underlyingErrorCode] = "\(underlyingError.code)"
            self[PixelKit.Parameters.underlyingErrorDomain] = underlyingError.domain
        } else if let sqlErrorCode = nsError.userInfo["NSSQLiteErrorDomain"] as? NSNumber {
            self[PixelKit.Parameters.underlyingErrorCode] = "\(sqlErrorCode.intValue)"
            self[PixelKit.Parameters.underlyingErrorDomain] = "NSSQLiteErrorDomain"
        }
    }

}
