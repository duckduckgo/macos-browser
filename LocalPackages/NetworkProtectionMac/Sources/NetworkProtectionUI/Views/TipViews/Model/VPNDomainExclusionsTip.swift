//
//  VPNDomainExclusionsTip.swift
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

import TipKit

/// A tip to suggest using domain exclusions when a site doesn't work.
///
struct VPNDomainExclusionsTip {}

@available(macOS 14.0, *)
extension VPNDomainExclusionsTip: Tip {

    @Parameter(.transient)
    static var vpnEnabled: Bool = false

    @Parameter(.transient)
    static var hasActiveSite: Bool = false

    /// This condition tries to verify that this tip is distanced from the previous tip and doesn't show right after.
    ///
    /// The conditions that will trigger this are:
    ///     - The status view was opened when previous tip's status is invalidated.
    ///     - The VPN is enabled when previous tip's status is invalidated.
    ///
    @Parameter
    static var isDistancedFromPreviousTip: Bool = false

    var id: String {
        "com.duckduckgo.vpn.tip.domainExclusions"
    }

    var title: Text {
        Text(UserText.networkProtectionDomainExclusionsTipTitle)
    }

    var message: Text? {
        Text(UserText.networkProtectionDomainExclusionsTipMessage)
    }

    var image: Image? {
        Image(.domainExclusionsTip)
    }

    var rules: [Self.Rule] {
        #Rule(Self.$hasActiveSite) {
            $0
        }
        #Rule(Self.$vpnEnabled) {
            $0
        }
        #Rule(Self.$isDistancedFromPreviousTip) {
            $0
        }
    }
}
