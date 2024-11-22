//
//  VPNAutoconnectTip.swift
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

/// A tip to suggest to the user to use the autoconnect option for the VPN.
///
struct VPNAutoconnectTip {}

@available(macOS 14.0, *)
extension VPNAutoconnectTip: Tip {

    enum ActionIdentifiers: String {
        case enable = "com.duckduckgo.vpn.tip.autoconnect.action.enable"
    }

    @Parameter
    static var geolocationTipDismissed: Bool = false

    @Parameter(.transient)
    static var vpnEnabled: Bool = false

    @Parameter
    static var vpnEnabledWhenDomainExclusionsAlreadyDismissed: Bool = false

    var id: String {
        "com.duckduckgo.vpn.tip.autoconnect"
    }

    var title: Text {
        Text("Connect Automatically")
    }

    var message: Text? {
        Text("The VPN can connect on its own when you log in to your computer.")
    }

    var image: Image? {
        Image(.autoconnectTip)
    }

    var actions: [Action] {
        [Action(id: ActionIdentifiers.enable.rawValue) {
            Text("Enable")
        }]
    }

    var rules: [Rule] {
        #Rule(Self.$vpnEnabled) {
            $0 == true
        }
        #Rule(Self.$vpnEnabledWhenDomainExclusionsAlreadyDismissed) {
            $0
        }
        #Rule(Self.$geolocationTipDismissed) {
            $0
        }
    }
}
