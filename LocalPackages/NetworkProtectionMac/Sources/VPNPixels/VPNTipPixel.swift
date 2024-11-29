//
//  VPNTipPixel.swift
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

public enum VPNTipStep: String {
    case shown
    case ignored
    case actioned
    case dismissed
}

public enum VPNTipPixel: VPNPixel {
    case autoconnectTip(step: VPNTipStep)
    case domainExclusionsTip(step: VPNTipStep)
    case geoswitchingTip(step: VPNTipStep)

    public var unscopedPixelName: String {
        switch self {
        case .autoconnectTip(let step):
            return "tip_autoconnect_\(step)"
        case .domainExclusionsTip(let step):
            return "tip_site-exclusion_\(step)"
        case .geoswitchingTip(let step):
            return "tip_geoswitching_\(step)"
        }
    }

    public var error: (any Error)? {
        nil
    }

    public var parameters: [String: String]? {
        nil
    }
}
