//
//  VPNFailureRecoveryPixel.swift
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
/// Ref: https://app.asana.com/0/0/1206939413299475/f
///
public enum VPNFailureRecoveryPixel: PixelKitEventV2 {

    /// This pixel is emitted when the last handshake diff is greater than n minutes and an attempt to recover is made (/register is called with failureRecovery)
    ///
    case vpnFailureRecoveryStarted

    /// This pixel is emitted when the recovery attempt failed due to any reason.
    ///
    case vpnFailureRecoveryFailed(Error)

    /// This pixel is emitted when the recovery attempt completed and the server was healthy and no further action needs to be taken.
    ///
    case vpnFailureRecoveryCompletedHealthy

    /// This pixel is emitted when the recovery attempt completed and the server was unhealthy resulting to reconnecting to a different server.
    ///
    case vpnFailureRecoveryCompletedUnhealthy

    public var name: String {
        switch self {
        case .vpnFailureRecoveryStarted:
            return "m_mac_netp_ev_failure_recovery_started"
        case .vpnFailureRecoveryFailed:
            return "m_mac_netp_ev_failure_recovery_failed"
        case .vpnFailureRecoveryCompletedHealthy:
            return "m_mac_netp_ev_failure_recovery_completed_server_healthy"
        case .vpnFailureRecoveryCompletedUnhealthy:
            return "m_mac_netp_ev_failure_recovery_completed_server_unhealthy"
        }
    }

    public var error: Error? {
        switch self {
        case .vpnFailureRecoveryStarted, .vpnFailureRecoveryCompletedHealthy, .vpnFailureRecoveryCompletedUnhealthy: return nil
        case .vpnFailureRecoveryFailed(let error): return error
        }
    }

    public var parameters: [String: String]? {
        nil
    }
}
