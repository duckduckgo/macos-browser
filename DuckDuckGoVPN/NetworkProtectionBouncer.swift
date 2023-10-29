//
//  NetworkProtectionBouncer.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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

import Common
import Foundation
import NetworkProtection
import ServiceManagement
import AppKit

/// Class that implements the necessary logic to ensure Network Protection is enabled, or prevent the app from running otherwise.
///
final class NetworkProtectionBouncer {

    /// Simply verifies that the Network Protection feature is enabled and if not, takes care of killing the
    /// current app.
    ///
    func requireAuthTokenOrKillApp() {
        let keychainStore = NetworkProtectionKeychainTokenStore(keychainType: .default, errorEvents: nil)

        guard keychainStore.isFeatureActivated else {
            os_log(.error, log: .networkProtection, "🔴 Stopping: Network Protection not authorized.")
            exit(EXIT_FAILURE)
        }
    }
}
