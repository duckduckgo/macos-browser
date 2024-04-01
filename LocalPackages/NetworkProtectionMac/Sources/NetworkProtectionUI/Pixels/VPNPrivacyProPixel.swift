//
//  VPNPrivacyProPixel.swift
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

/// PrivacyPro pixels.
///
/// Ref: https://app.asana.com/0/0/1206836019887720/f
///
public enum VPNPrivacyProPixel: PixelKitEventV2 {

    /// Fired when PrivacyPro VPN access is revoked, and the dialog is shown.
    ///
    case vpnAccessRevokedDialogShown

    /// Fired only once when the VPN beta becomes disabled due to the start of PrivacyPro..
    ///
    case vpnBetaStoppedWhenPrivacyProEnabled

    public var name: String {
        switch self {
        case .vpnAccessRevokedDialogShown:
            return "vpn_access_revoked_dialog_shown"
        case .vpnBetaStoppedWhenPrivacyProEnabled:
            return "vpn_beta_stopped_when_privacy_pro_enabled"
        }
    }

    public var error: Error? {
        nil
    }

    public var parameters: [String: String]? {
        nil
    }
}
