//
//  Pixel.swift
//
//  Copyright © 2018 DuckDuckGo. All rights reserved.
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

public protocol PixelEvent {
    var name: String { get }
    var parameters: [String: String]? { get }
}

extension URL {
    // MARK: Pixel

    static let pixelBase = ProcessInfo.processInfo.environment["PIXEL_BASE_URL", default: "https://improving.duckduckgo.com"]

    public static func pixelUrl(forPixelNamed pixelName: String) -> URL {
        let urlString = "\(Self.pixelBase)/t/\(pixelName)"
        let url = URL(string: urlString)!
        // url = url.addParameter(name: \"atb\", value: statisticsStore.atbWithVariant ?? \"\")")
        // https://app.asana.com/0/1177771139624306/1199951074455863/f
        return url
    }
}

public final class Pixel {

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

    public typealias Event = PixelEvent

    static let duckDuckGoMorePrivacyInfo = URL(string: "https://help.duckduckgo.com/duckduckgo-help-pages/privacy/atb/")!

    public private(set) static var shared: Pixel?
    private let appVersion: String
    private let defaultHeaders: [String: String]
    private let log: OSLog
    private let fireRequest: FireRequest

    public static func setUp(dryRun: Bool = false, appVersion: String, defaultHeaders: [String: String], log: OSLog, fireRequest: @escaping FireRequest) {
        shared = Pixel(dryRun: dryRun, appVersion: appVersion, defaultHeaders: defaultHeaders, log: log, fireRequest: fireRequest)
    }

    static func tearDown() {
        shared = nil
    }

    private var dryRun: Bool

    init(dryRun: Bool, appVersion: String, defaultHeaders: [String: String], log: OSLog, fireRequest: @escaping FireRequest) {
        self.dryRun = dryRun
        self.appVersion = appVersion
        self.defaultHeaders = defaultHeaders
        self.log = log
        self.fireRequest = fireRequest
    }

    public func fire(pixelNamed pixelName: String,
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

        fireRequest(pixelName,
                    headers,
                    newParams,
                    allowedQueryReservedCharacters,
                    true,
                    onComplete)
    }

    public static func fire(_ event: Pixel.Event,
                            withHeaders headers: [String: String],
                            withAdditionalParameters parameters: [String: String]? = nil,
                            allowedQueryReservedCharacters: CharacterSet? = nil,
                            includeAppVersionParameter: Bool = true,
                            onComplete: @escaping (Error?) -> Void = {_ in }) {
        let newParams: [String: String]?
        switch (event.parameters, parameters) {
        case (.some(let parameters), .none):
            newParams = parameters
        case (.none, .some(let parameters)):
            newParams = parameters
        case (.some(let params1), .some(let params2)):
            newParams = params1.merging(params2) { $1 }
        case (.none, .none):
            newParams = nil
        }

        Self.shared?.fire(pixelNamed: event.name,
                          withHeaders: headers,
                          withAdditionalParameters: newParams,
                          allowedQueryReservedCharacters: allowedQueryReservedCharacters,
                          includeAppVersionParameter: includeAppVersionParameter,
                          onComplete: onComplete)
    }

}
