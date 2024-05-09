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
protocol InstallationAttributionsPixelHandler: AnyObject {
    /// Fire the Pixel to track the App install.
    func fireInstallationAttributionPixel()
}

extension GenericAttributionPixelHandler: InstallationAttributionsPixelHandler {

    func fireInstallationAttributionPixel() {
        fireAttributionPixel(
            event: GeneralPixel.installationAttribution,
            frequency: .legacyInitial,
            parameters: nil
        )
    }

}

extension GenericAttributionPixelHandler {
    static let installation = GenericAttributionPixelHandler(originProvider: AttributionOriginFileProvider())
}
