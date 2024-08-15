//
//  DomainExclusionsEngagement.swift
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
public enum DomainExclusionsEngagement: VPNPixel {

    case excluded(_ domain: String)
    case included(_ domain: String)

    public init(exclude: Bool, domain: String) {
        if exclude {
            self = .excluded(domain)
        } else {
            self = .included(domain)
        }
    }

    // The name is provided by the convenience implementation in VPNPixel,
    // so we don't need to implement it here.
    //
    // var name: String

    public var unscopedPixelName: String {
        switch self {
        case .excluded:
            return "domain_excluded"

        case .included:
            return "domain_included"
        }
    }

    public var parameters: [String: String]? {
        switch self {
        case .excluded(let domain),
                .included(let domain):
            [PixelKit.Parameters.domain: domain]
        }
    }

    public var error: Error? {
        return nil
    }
}
