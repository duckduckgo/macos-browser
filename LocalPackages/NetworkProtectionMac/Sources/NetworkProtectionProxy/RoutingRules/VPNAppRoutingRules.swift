//
//  VPNAppRoutingRules.swift
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

public typealias VPNAppRoutingRules = [VPNRoutingAppIdentifier: VPNRoutingRule]

/// An instance that identifies a specific app
///
/// For now this class only includes the bundle ID for the apps to apply rules to, but
/// malicious apps may spoof the bundle ID, which means we need to consider adding
/// other identifying data in this structure if possible.
///
public struct VPNRoutingAppIdentifier: Codable, Hashable, Equatable {
    public let bundleID: String

    public init(bundleID: String) {
        self.bundleID = bundleID
    }
}
