//
//  AttributionsPixel.swift
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

enum AttributionsPixel {
    /// Used to track installation without tracking retention.
    case installation(origin: String?, locale: String)
}

extension AttributionsPixel: PixelKitEventV2 {

    var name: String {
        switch self {
        case .installation:
            return "m_mac_install"
        }
    }

    var parameters: [String: String]? {
        switch self {
        case let .installation(origin, locale):
            var dictionary = [PixelKit.Parameters.locale: locale]
            if let origin {
                dictionary[PixelKit.Parameters.origin] = origin
            }
            return dictionary
        }
    }

    var error: Error? {
        return nil
    }

}
