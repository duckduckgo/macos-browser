//
//  AttributionPixelHandler.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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
import PixelKit

// A type that send pixels that needs attributions parameters.
protocol AttributionPixelHandler {
    func fireAttributionPixel(
        event: PixelKit.Event,
        frequency: PixelKit.Frequency,
        origin: String?,
        additionalParameters: [String: String]?
    )
}

final class GenericAttributionPixelHandler: AttributionPixelHandler {
    enum Parameters {
        static let origin = "origin"
        static let locale = "locale"
    }

    private let fireRequest: FireRequest
    private let locale: Locale

    /// Creates an instance with the specified fire request, origin provider and locale.
    /// - Parameters:
    ///   - fireRequest: A function for sending the Pixel request.
    ///   - locale: The locale of the device.
    init(
        fireRequest: @escaping FireRequest = PixelKit.fire,
        locale: Locale = .current
    ) {
        self.fireRequest = fireRequest
        self.locale = locale
    }

    func fireAttributionPixel(
        event: PixelKit.Event,
        frequency: PixelKit.Frequency,
        origin: String?,
        additionalParameters: [String: String]?
    ) {
        fireRequest(
            event,
            frequency,
            [:],
            self.parameters(additionalParameters, withOrigin: origin, locale: locale.identifier),
            nil,
            nil,
            true, { _, _ in }
        )
    }
}

// MARK: - Parameter

private extension GenericAttributionPixelHandler {
    func parameters(_ parameters: [String: String]?, withOrigin origin: String?, locale: String) -> [String: String] {
        var parameters = parameters ?? [:]
        parameters[Self.Parameters.locale] = locale
        if let origin {
            parameters[Self.Parameters.origin] = origin
        }
        return parameters
    }
}

// MARK: - FireRequest

extension GenericAttributionPixelHandler {
    typealias FireRequest = (
        _ event: PixelKit.Event,
        _ frequency: PixelKit.Frequency,
        _ headers: [String: String],
        _ parameters: [String: String]?,
        _ error: Error?,
        _ allowedQueryReservedCharacters: CharacterSet?,
        _ includeAppVersionParameter: Bool,
        _ onComplete: @escaping (Bool, Error?) -> Void
    ) -> Void
}
