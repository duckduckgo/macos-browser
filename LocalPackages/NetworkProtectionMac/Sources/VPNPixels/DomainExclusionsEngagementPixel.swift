//
//  DomainExclusionsEngagementPixel.swift
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
public enum DomainExclusionsEngagementPixel: VPNPixel {

    /// One or more exclusions were added.
    ///
    case exclusionAdded

    /// One or more exclusions were removed.
    ///
    case exclusionRemoved

    public init(added: Bool) {
        self = added ? .exclusionAdded : .exclusionRemoved
    }

    // The name is provided by the convenience implementation in VPNPixel,
    // so we don't need to implement it here.
    //
    // var name: String

    public var unscopedPixelName: String {
        switch self {
        case .exclusionAdded:
            return "domain_exclusion_enabled"
        case .exclusionRemoved:
            return "domain_exclusion_disabled"
        }
    }

    public var parameters: [String: String]? {
        switch self {
        case .exclusionAdded:
            return [:]
        case .exclusionRemoved:
            return [:]
        }
    }

    public var error: Error? {
        return nil
    }
}
