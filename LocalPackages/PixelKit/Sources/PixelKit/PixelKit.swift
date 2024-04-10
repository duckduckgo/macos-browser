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
    ///
    public enum Frequency {
        /// The default frequency for pixels. This fires pixels with the event names as-is.
        case standard

        /// Sent only once ever. The timestamp for this pixel is stored. Name for pixels of this type must end with `_u`.
        case justOnce

        /// Sent once per day. The last timestamp for this pixel is stored and compared to the current date. Pixels of this type will have `_d` appended to their name.
        case dailyOnly

        /// Sent once per day with a `_d` suffix, in addition to every time it is called with a `_c` suffix.
        /// This means a pixel will get sent twice the first time it is called per-day, and subsequent calls that day will only send the `_c` variant.
        /// This is useful in situations where pixels receive spikes in volume, as the daily pixel can be used to determine how many users are actually affected.
        case dailyAndContinuous
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
    ///
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

    private static let defaultDailyPixelCalendar: Calendar = {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private static let weeksToCoalesceCohort = 6

    private let dateGenerator: () -> Date

    public private(set) static var shared: PixelKit?
    private let appVersion: String
    private let defaultHeaders: [String: String]
    private let log: OSLog
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
                             log: OSLog,
                             dailyPixelCalendar: Calendar? = nil,
                             dateGenerator: @escaping () -> Date = Date.init,
                             defaults: UserDefaults,
                             fireRequest: @escaping FireRequest) {
        shared = PixelKit(dryRun: dryRun,
                          appVersion: appVersion,
                          source: source,
                          defaultHeaders: defaultHeaders,
                          log: log,
                          dailyPixelCalendar: dailyPixelCalendar,
                          dateGenerator: dateGenerator,
                          defaults: defaults,
                          fireRequest: fireRequest)
    }

    static func tearDown() {
        shared = nil
    }

    private var dryRun: Bool
    private let source: String?
    private let pixelCalendar: Calendar

    init(dryRun: Bool,
         appVersion: String,
         source: String? = nil,
         defaultHeaders: [String: String],
         log: OSLog,
         dailyPixelCalendar: Calendar? = nil,
         dateGenerator: @escaping () -> Date = Date.init,
         defaults: UserDefaults,
         fireRequest: @escaping FireRequest) {

        self.dryRun = dryRun
        self.appVersion = appVersion
        self.source = source
        self.defaultHeaders = defaultHeaders
        self.log = log
        self.pixelCalendar = dailyPixelCalendar ?? Self.defaultDailyPixelCalendar
        self.dateGenerator = dateGenerator
        self.defaults = defaults
        self.fireRequest = fireRequest
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func fire(pixelNamed pixelName: String,
                      frequency: Frequency,
                      withHeaders headers: [String: String]?,
                      withAdditionalParameters params: [String: String]?,
                      withError error: Error?,
                      allowedQueryReservedCharacters: CharacterSet?,
                      includeAppVersionParameter: Bool,
                      onComplete: @escaping CompletionBlock) {

        var newParams = params ?? [:]

        if includeAppVersionParameter {
            newParams[Parameters.appVersion] = appVersion
        }

        if let source {
            newParams[Parameters.pixelSource] = source
        }

        if let error {
            newParams.appendErrorPixelParams(error: error)
        }

        #if DEBUG
            newParams[Parameters.test] = Values.test
        #endif

        var headers = headers ?? defaultHeaders
        headers[Header.moreInfo] = "See " + Self.duckDuckGoMorePrivacyInfo.absoluteString
        headers[Header.client] = "macOS"

        switch frequency {
        case .standard:
            fireRequestWrapper(pixelName, headers, newParams, allowedQueryReservedCharacters, true, onComplete)
        case .justOnce:
            guard pixelName.hasSuffix("_u") else {
                assertionFailure("Unique pixel: must end with _u")
                return
            }
            if !pixelHasBeenFiredEver(pixelName) {
                fireRequestWrapper(pixelName, headers, newParams, allowedQueryReservedCharacters, true, onComplete)
                updatePixelLastFireDate(pixelName: pixelName)
            } else {
                printDebugInfo(pixelName: pixelName, parameters: newParams, skipped: true)
            }
        case .dailyOnly:
            if !pixelHasBeenFiredToday(pixelName) {
                fireRequestWrapper(pixelName + "_d", headers, newParams, allowedQueryReservedCharacters, true, onComplete)
                updatePixelLastFireDate(pixelName: pixelName)
            } else {
                printDebugInfo(pixelName: pixelName + "_d", parameters: newParams, skipped: true)
            }
        case .dailyAndContinuous:
            if !pixelHasBeenFiredToday(pixelName) {
                fireRequestWrapper(pixelName + "_d", headers, newParams, allowedQueryReservedCharacters, true, onComplete)
                updatePixelLastFireDate(pixelName: pixelName)
            } else {
                printDebugInfo(pixelName: pixelName + "_d", parameters: newParams, skipped: true)
            }

            fireRequestWrapper(pixelName + "_c", headers, newParams, allowedQueryReservedCharacters, true, onComplete)
        }
    }

    private func printDebugInfo(pixelName: String, parameters: [String: String], skipped: Bool = false) {
#if DEBUG
        let params = parameters.filter { key, _ in !["test"].contains(key) }
        os_log(.debug, log: log, "👾 [%{public}@] %{public}@ %{public}@", skipped ? "SKIPPED" : "FIRED", pixelName.replacingOccurrences(of: "_", with: "."), params)
#endif
    }

    private func fireRequestWrapper(
        _ pixelName: String,
        _ headers: [String: String],
        _ parameters: [String: String],
        _ allowedQueryReservedCharacters: CharacterSet?,
        _ callBackOnMainThread: Bool,
        _ onComplete: @escaping CompletionBlock) {
        guard !dryRun else {
            printDebugInfo(pixelName: pixelName, parameters: parameters)

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
            if frequency == .dailyOnly, pixelHasBeenFiredToday(pixelName) {
                onComplete(false, nil)
                return
            } else if frequency == .justOnce, pixelHasBeenFiredEver(pixelName) {
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

    private func cohort(from cohortLocalDate: Date?, dateGenerator: () -> Date = Date.init) -> String? {
        guard let cohortLocalDate,
              let baseDate = pixelCalendar.date(from: .init(year: 2023, month: 1, day: 1)),
              let weeksSinceCohortAssigned = pixelCalendar.dateComponents([.weekOfYear], from: cohortLocalDate, to: dateGenerator()).weekOfYear,
              let assignedCohort = pixelCalendar.dateComponents([.weekOfYear], from: baseDate, to: cohortLocalDate).weekOfYear else {
            return nil
        }

        if weeksSinceCohortAssigned > Self.weeksToCoalesceCohort {
            return ""
        } else {
            return "week-" + String(assignedCohort + 1)
        }
    }

    public static func cohort(from cohortLocalDate: Date?, dateGenerator: () -> Date = Date.init) -> String {
        Self.shared?.cohort(from: cohortLocalDate, dateGenerator: dateGenerator) ?? ""
    }

    public static func pixelLastFireDate(event: Event) -> Date? {
        Self.shared?.pixelLastFireDate(event: event)
    }

    public func pixelLastFireDate(pixelName: String) -> Date? {
        defaults.object(forKey: userDefaultsKeyName(forPixelName: pixelName)) as? Date
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

    private func userDefaultsKeyName(forPixelName pixelName: String) -> String {
        dryRun
            ? "com.duckduckgo.network-protection.pixel.\(pixelName).dry-run"
            : "com.duckduckgo.network-protection.pixel.\(pixelName)"
    }

}

extension Dictionary where Key == String, Value == String {

    mutating func appendErrorPixelParams(error: Error) {
        self.merge(error.pixelParameters) { _, second in
            return second
        }
    }
}
