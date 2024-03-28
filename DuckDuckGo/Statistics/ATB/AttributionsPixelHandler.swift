//
//  AttributionsPixelHandler.swift
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

protocol AttributionsPixelHandler: AnyObject {
    func fireInstallationAttributionPixel()
}

final class InstallationAttributionPixelHandler: AttributionsPixelHandler {
    private let fireRequest: FireRequest
    private let originProvider: AttributionOriginProvider
    private let locale: Locale

    init(
        fireRequest: @escaping FireRequest = PixelKit.fire,
        originProvider: AttributionOriginProvider = DiskAttributionOriginProvider(),
        locale: Locale = .current
    ) {
        self.fireRequest = fireRequest
        self.originProvider = originProvider
        self.locale = locale
    }

    func fireInstallationAttributionPixel() {
        fireRequest(AttributionsPixel.installation(origin: originProvider.origin, locale: locale.identifier), .justOnce, [:], nil, nil, nil, true, {_, _ in })
    }
}

extension InstallationAttributionPixelHandler {
    typealias FireRequest = (
        _ event: PixelKit.Event,
        _ frequency: PixelKit.Frequency,
        _ headers: [String: String],
        _ parameters: [String: String]?,
        _ error: Error?,
        _ allowedQueryReservedCharacters: CharacterSet?,
        _ includeAppVersionParameter: Bool,
        _ onComplete: @escaping PixelKit.CompletionBlock
    ) -> Void
}
