//
//  VPNDomainExclusionsTip.swift
//  DuckDuckGo
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

    /// Whether the tip can be shown.
    ///
    /// This tip is not shown for the VPN menu app.
    ///
    @Parameter(.transient)
    static var canShow: Bool = false

    static let geolocationTipDismissedEvent = Tips.Event(id: "com.duckduckgo.vpn.tip.domainExclusions.geolocationTipDismissedEvent")

    /// The containing view was opened when the VPN was already connected.
    ///
    /// This condition may be indicative that the user is struggling, so they might want
    /// to exclude a site.
    ///
    static let viewOpenedWhenVPNAlreadyConnectedEvent = Tips.Event(id: "com.duckduckgo.vpn.tip.domainExclusions.popoverOpenedWhileAlreadyConnected")

    var id: String {
        "com.duckduckgo.vpn.tip.domainExclusions"
    }

    var title: Text {
        Text("Website not working?")
    }

    var message: Text? {
        Text("Exclude websites that block VPN traffic so you can use them without turning the VPN off.")
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
        #Rule(Self.$canShow) {
            $0
        }
        #Rule(Self.geolocationTipDismissedEvent) {
            $0.donations.count > 0
        }
        #Rule(Self.viewOpenedWhenVPNAlreadyConnectedEvent) {
            $0.donations.count > 0
        }
    }
}
