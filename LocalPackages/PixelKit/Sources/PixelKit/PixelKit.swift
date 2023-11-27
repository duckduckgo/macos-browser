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
    }

    /// A closure typealias to request sending pixels through the network.
    ///
    public typealias FireRequest = (
        _ pixelName: String,
        _ headers: [String: String],
        _ parameters: [String: String],
        _ allowedQueryReservedCharacters: CharacterSet?,
        _ callBackOnMainThread: Bool,
        _ onComplete: @escaping (Error?) -> Void) -> Void

    public typealias Event = PixelKitEvent

    public static let duckDuckGoMorePrivacyInfo = URL(string: "https://help.duckduckgo.com/duckduckgo-help-pages/privacy/atb/")!

    private let defaults: UserDefaults

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

    public private(set) static var shared: PixelKit?
    private let appVersion: String
    private let defaultHeaders: [String: String]
    private let log: OSLog
    private let fireRequest: FireRequest

    public static func setUp(dryRun: Bool = false, appVersion: String, defaultHeaders: [String: String], log: OSLog, defaults: UserDefaults, fireRequest: @escaping FireRequest) {
        shared = PixelKit(dryRun: dryRun, appVersion: appVersion, defaultHeaders: defaultHeaders, log: log, defaults: defaults, fireRequest: fireRequest)
    }

    static func tearDown() {
        shared = nil
    }

    private var dryRun: Bool
    private let pixelCalendar: Calendar

    init(dryRun: Bool,
         appVersion: String,
         defaultHeaders: [String: String],
         log: OSLog,
         dailyPixelCalendar: Calendar? = nil,
         defaults: UserDefaults,
         fireRequest: @escaping FireRequest) {

        self.dryRun = dryRun
        self.appVersion = appVersion
        self.defaultHeaders = defaultHeaders
        self.log = log
        self.pixelCalendar = dailyPixelCalendar ?? Self.defaultDailyPixelCalendar
        self.defaults = defaults
        self.fireRequest = fireRequest
    }

    private func fire(pixelNamed pixelName: String,
                      frequency: Frequency,
                      withHeaders headers: [String: String]? = nil,
                      withAdditionalParameters params: [String: String]? = nil,
                      allowedQueryReservedCharacters: CharacterSet? = nil,
                      includeAppVersionParameter: Bool = true,
                      onComplete: @escaping (Error?) -> Void = {_ in }) {

        var newParams = params ?? [:]
        if includeAppVersionParameter {
            newParams[Parameters.appVersion] = appVersion
        }
        #if DEBUG
            newParams[Parameters.test] = Values.test
        #endif

        var headers = headers ?? defaultHeaders
        headers[Header.moreInfo] = "See " + Self.duckDuckGoMorePrivacyInfo.absoluteString

        guard !dryRun else {
            let params = params?.filter { key, _ in !["appVersion", "test"].contains(key) } ?? [:]
            os_log(.debug, log: log, "%@ %@", pixelName.replacingOccurrences(of: "_", with: "."), params)

            // simulate server response time for Dry Run mode
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                onComplete(nil)
            }

            return
        }

        switch frequency {
        case .standard:
            fireRequest(pixelName, headers, newParams, allowedQueryReservedCharacters, true, onComplete)
        case .justOnce:
            guard pixelName.hasSuffix("_u") else {
                assertionFailure("Unique pixel: must end with _u")
                return
            }
            if !pixelHasBeenFiredEver(pixelName) {
                fireRequest(pixelName, headers, newParams, allowedQueryReservedCharacters, true, { _ in })
                updatePixelLastFireDate(pixelName: pixelName)
            }
        case .dailyOnly:
            if !pixelHasBeenFiredToday(pixelName) {
                fireRequest(pixelName + "_d", headers, newParams, allowedQueryReservedCharacters, true, { _ in })
                updatePixelLastFireDate(pixelName: pixelName)
            }
        case .dailyAndContinuous:
            if !pixelHasBeenFiredToday(pixelName) {
                fireRequest(pixelName + "_d", headers, newParams, allowedQueryReservedCharacters, true, { _ in })
                updatePixelLastFireDate(pixelName: pixelName)
            }

            fireRequest(pixelName + "_c", headers, newParams, allowedQueryReservedCharacters, true, onComplete)
        }
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
                     allowedQueryReservedCharacters: CharacterSet? = nil,
                     includeAppVersionParameter: Bool = true,
                     onComplete: @escaping (Error?) -> Void = {_ in }) {

        let pixelName = prefixedName(for: event)

        if !dryRun {
            if frequency == .dailyOnly, pixelHasBeenFiredToday(pixelName) {
                onComplete(nil)
                return
            } else if frequency == .justOnce, pixelHasBeenFiredEver(pixelName) {
                onComplete(nil)
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

        fire(pixelNamed: pixelName,
             frequency: frequency,
             withHeaders: headers,
             withAdditionalParameters: newParams,
             allowedQueryReservedCharacters: allowedQueryReservedCharacters,
             includeAppVersionParameter: includeAppVersionParameter,
             onComplete: onComplete)
    }

    public static func fire(_ event: Event,
                            frequency: Frequency = .standard,
                            withHeaders headers: [String: String] = [:],
                            withAdditionalParameters parameters: [String: String]? = nil,
                            allowedQueryReservedCharacters: CharacterSet? = nil,
                            includeAppVersionParameter: Bool = true,
                            onComplete: @escaping (Error?) -> Void = {_ in }) {

        Self.shared?.fire(event,
                          frequency: frequency,
                          withHeaders: headers,
                          withAdditionalParameters: parameters,
                          allowedQueryReservedCharacters: allowedQueryReservedCharacters,
                          includeAppVersionParameter: includeAppVersionParameter,
                          onComplete: onComplete)
    }

    private func dateString(for event: Event) -> String? {
        let pixelName = prefixedName(for: event)

        guard let dateFired = pixelLastFireDate(pixelName: pixelName) else {
            return nil
        }

        return dateFormatter.string(from: dateFired)
    }

    public static func dateString(for event: Event) -> String {
        Self.shared?.dateString(for: event) ?? ""
    }

    public func pixelLastFireDate(pixelName: String) -> Date? {
        defaults.object(forKey: userDefaultsKeyName(forPixelName: pixelName)) as? Date
    }

    private func updatePixelLastFireDate(pixelName: String) {
        defaults.set(Date(), forKey: userDefaultsKeyName(forPixelName: pixelName))
    }

    private func pixelHasBeenFiredToday(_ name: String) -> Bool {
        if let lastFireDate = pixelLastFireDate(pixelName: name) {
            return pixelCalendar.isDate(Date(), inSameDayAs: lastFireDate)
        }

        return false
    }

    private func pixelHasBeenFiredEver(_ name: String) -> Bool {
        pixelLastFireDate(pixelName: name) != nil
    }

    private func userDefaultsKeyName(forPixelName pixelName: String) -> String {
        return "com.duckduckgo.network-protection.pixel.\(pixelName)"
    }

}
