//
//  InstallationAttributionPixelHandler.swift
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

/// A type that handles Pixels for acquisition attributions.
protocol AttributionsPixelHandler: AnyObject {
    /// Fire the Pixel to track the App install.
    func fireInstallationAttributionPixel()
}

final class InstallationAttributionPixelHandler: AttributionsPixelHandler {
    enum Parameters {
        static let origin = "origin"
        static let locale = "locale"
    }

    private let fireRequest: FireRequest
    private let originProvider: AttributionOriginProvider
    private let locale: Locale

    /// Creates an instance with the specified fire request, origin provider and locale.
    /// - Parameters:
    ///   - fireRequest: A function for sending the Pixel request.
    ///   - originProvider: A provider for the origin used to track the acquisition funnel.
    ///   - locale: The locale of the device.
    init(
        fireRequest: @escaping FireRequest = PixelKit.fire,
        originProvider: AttributionOriginProvider = AttributionOriginFileProvider(),
        locale: Locale = .current
    ) {
        self.fireRequest = fireRequest
        self.originProvider = originProvider
        self.locale = locale
    }

    func fireInstallationAttributionPixel() {
        fireRequest(
            GeneralPixel.installationAttribution,
            .legacyInitial,
            [:],
            additionalParameters(origin: originProvider.origin, locale: locale.identifier),
            nil,
            nil,
            true, { _, _ in }
        )
    }
}

// MARK: - Parameter

private extension InstallationAttributionPixelHandler {
    func additionalParameters(origin: String?, locale: String) -> [String: String] {
        var dictionary = [Self.Parameters.locale: locale]
        if let origin {
            dictionary[Self.Parameters.origin] = origin
        }
        return dictionary
    }
}

// MARK: - FireRequest

extension InstallationAttributionPixelHandler {
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
