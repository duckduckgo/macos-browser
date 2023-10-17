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

        /// Sent once per day. The last timestamp for this pixel is stored and compared to the current date. Pixels of this type will have `_d` appended to their name.
        case dailyOnly

        /// Sent once per day with a `_d` suffix, in addition to every time it is called with a `_c` suffix.
        /// This means a pixel will get sent twice the first time it is called per-day, and subsequent calls that day will only send the `_c` variant.
        /// This is useful in situations where pixels receive spikes in volume, as the daily pixel can be used to determine how many users are actually affected.
        case dailyAndContinuous
    }

    enum Header {
        static let acceptEncoding = "Accept-Encoding"
        static let acceptLanguage = "Accept-Language"
        static let userAgent = "User-Agent"
        static let ifNoneMatch = "If-None-Match"
        static let moreInfo = "X-DuckDuckGo-MoreInfo"
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

    static let duckDuckGoMorePrivacyInfo = URL(string: "https://help.duckduckgo.com/duckduckgo-help-pages/privacy/atb/")!

    private let defaults: UserDefaults

    private static let defaultDailyPixelCalendar: Calendar = {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    public private(set) static var shared: PixelKit?
    private let appVersion: String
    private let defaultHeaders: [String: String]
    private let log: OSLog
    private let fireRequest: FireRequest

    public static func setUp(dryRun: Bool = false, appVersion: String, defaultHeaders: [String: String], log: OSLog, fireRequest: @escaping FireRequest) {
        shared = PixelKit(dryRun: dryRun, appVersion: appVersion, defaultHeaders: defaultHeaders, log: log, fireRequest: fireRequest)
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
         defaults: UserDefaults = .standard,
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
                      dailyPixelCalendar: Calendar? = nil,
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
        case .dailyOnly:
            updatePixelLastFireDate(pixelName: pixelName)
            fireRequest(pixelName + "_d", headers, newParams, allowedQueryReservedCharacters, true, onComplete)
        case .dailyAndContinuous:
            if !pixelHasBeenFiredToday(pixelName, dailyPixelStorage: defaults, calendar: self.pixelCalendar) {
                fireRequest(pixelName + "_d", headers, newParams, allowedQueryReservedCharacters, true, { _ in })
            }

            updatePixelLastFireDate(pixelName: pixelName)

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
                     frequency: Frequency,
                     withHeaders headers: [String: String]? = nil,
                     withAdditionalParameters params: [String: String]? = nil,
                     allowedQueryReservedCharacters: CharacterSet? = nil,
                     includeAppVersionParameter: Bool = true,
                     dailyPixelCalendar: Calendar? = nil,
                     onComplete: @escaping (Error?) -> Void = {_ in }) {

        let pixelName = prefixedName(for: event)

        if frequency == .dailyOnly, pixelHasBeenFiredToday(pixelName, dailyPixelStorage: defaults, calendar: self.pixelCalendar) {
            onComplete(nil)
            return
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
             dailyPixelCalendar: dailyPixelCalendar,
             onComplete: onComplete)
    }

    public static func fire(_ event: Event,
                            frequency: Frequency,
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

    private func updatePixelLastFireDate(pixelName: String) {
        defaults.set(Date(), forKey: userDefaultsKeyName(forPixelName: pixelName))
    }

    private func pixelHasBeenFiredToday(_ name: String, dailyPixelStorage: UserDefaults, calendar: Calendar) -> Bool {
        if let lastFireDate = dailyPixelStorage.object(forKey: userDefaultsKeyName(forPixelName: name)) as? Date {
            return calendar.isDate(Date(), inSameDayAs: lastFireDate)
        }

        return false
    }

    private func userDefaultsKeyName(forPixelName pixelName: String) -> String {
        return "com.duckduckgo.network-protection.pixel.\(pixelName)"
    }

}
