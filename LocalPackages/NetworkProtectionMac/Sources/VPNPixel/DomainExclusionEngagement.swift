//
//  DomainExclusionEngagement.swift
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

/// Pixels to understand domain exclusion engagement
///
enum DomainExclusionEngagement: PixelKitEventV2 {
    case excluded(_ domain: String)
    case included(_ domain: String)

    var name: String {
        switch self {
        case .excluded:
            return "vpn_domain_excluded"

        case .included:
            return "vpn_domain_included"
        }
    }

    var parameters: [String: String]? {
        return nil
    }

    var error: Error? {
        switch self {
        case .begin,
                .success:
            return nil
        case .failure(let error):
            return error
        }
    }
}
