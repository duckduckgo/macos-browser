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
import Networking
import Common
import PixelKit

final class Pixel {

    static private(set) var shared: Pixel?

    static func setUp(dryRun: Bool = false) {
#if DEBUG
        if dryRun {
            shared = Pixel(store: LocalPixelDataStore.shared) { event, params, _, _, onComplete in
                let params = params.filter { key, _ in !["appVersion", "test"].contains(key) }
                os_log(.debug, log: .pixel, "%@ %@", event.name.replacingOccurrences(of: "_", with: "."), params)
                // simulate server response time for Dry Run mode
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    onComplete(nil)
                }
            }
            return
        }
#endif
        shared = Pixel(store: LocalPixelDataStore.shared, requestSender: Pixel.defaultRequestSender)
    }

#if DEBUG
    static func setUp(store: @escaping @autoclosure () -> PixelDataStore = { fatalError("provide test store") }(),
                      pixelFired: @escaping (Pixel.Event) -> Void) {
        shared = Pixel(store: store()) { event, _, _, _, onComplete in
            pixelFired(event)
            onComplete(nil)
        }
    }
#endif

    static func tearDown() {
        shared?.store = nil
        shared = nil
    }

    typealias RequestSender = (Pixel.Event, [String: String], CharacterSet?, APIRequest.Headers, @escaping (Error?) -> Void) -> Void
    private let sendRequest: RequestSender

    private var store: (() -> PixelDataStore)!

    static var isNewUser: Bool {
        let oneWeekAgo = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date())!
        return firstLaunchDate >= oneWeekAgo
    }

    static var defaultRequestSender: RequestSender {
        { event, params, allowedQueryReservedCharacters, headers, onComplete in
            let configuration = APIRequest.Configuration(url: URL.pixelUrl(forPixelNamed: event.name),
                                                         queryParameters: params,
                                                         allowedQueryReservedCharacters: allowedQueryReservedCharacters,
                                                         headers: headers)
            let request = APIRequest(configuration: configuration, urlSession: URLSession.session(useMainThreadCallbackQueue: true))
            request.fetch { (_, error) in
                onComplete(error)
            }
        }
    }

    init(store: @escaping @autoclosure () -> PixelDataStore, requestSender: @escaping RequestSender) {
        self.store = store
        self.sendRequest = requestSender
    }

    private static let moreInfoHeader: HTTPHeaders = [APIRequest.HTTPHeaderField.moreInfo: "See " + URL.duckDuckGoMorePrivacyInfo.absoluteString]

    // Temporary for activation pixels
    static private var aMonthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
    @UserDefaultsWrapper(key: .firstLaunchDate, defaultValue: aMonthAgo)
    static var firstLaunchDate: Date

    func fire(_ event: Pixel.Event,
              limitTo limit: Pixel.Event.Repetition = .repetitive,
              withAdditionalParameters parameters: [String: String]? = nil,
              allowedQueryReservedCharacters: CharacterSet? = nil,
              includeAppVersionParameter: Bool = true,
              withHeaders headers: APIRequest.Headers = APIRequest.Headers(additionalHeaders: moreInfoHeader),
              onComplete: @escaping (Error?) -> Void = {_ in }) {

        func repetition() -> Event.Repetition {
            Event.Repetition(key: event.name, store: self.store())
        }
        switch limit {
        case .initial:
            if repetition() != .initial { return }
        case .dailyFirst:
            if repetition() == .repetitive { return } // Pixel alredy fired today
        case .repetitive: break
        }

        var newParams: [String: String]
        switch (event.parameters, parameters) {
        case (.some(let parameters), .none):
            newParams = parameters
        case (.none, .some(let parameters)):
            newParams = parameters
        case (.some(let params1), .some(let params2)):
            newParams = params1.merging(params2) { $1 }
        case (.none, .none):
            newParams = [:]
        }

        if includeAppVersionParameter {
            newParams[PixelKit.Parameters.appVersion] = AppVersion.shared.versionNumber
        }
#if DEBUG
        newParams[PixelKit.Parameters.test] = PixelKit.Values.test
#endif

        sendRequest(event, newParams, allowedQueryReservedCharacters, headers, onComplete)
    }

    static func fire(_ event: Pixel.Event,
                     limitTo limit: Pixel.Event.Repetition = .repetitive,
                     withAdditionalParameters parameters: [String: String]? = nil,
                     allowedQueryReservedCharacters: CharacterSet? = nil,
                     includeAppVersionParameter: Bool = true,
                     onComplete: @escaping (Error?) -> Void = {_ in }) {

        Self.shared?.fire(event,
                          limitTo: limit,
                          withAdditionalParameters: parameters,
                          allowedQueryReservedCharacters: allowedQueryReservedCharacters,
                          includeAppVersionParameter: includeAppVersionParameter,
                          onComplete: onComplete)
    }

}

public func pixelAssertionFailure(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line) {
    Pixel.fire(.debug(event: Pixel.Event.Debug.assertionFailure(message: message(), file: file, line: line)))
    Swift.assertionFailure(message(), file: file, line: line)
}
