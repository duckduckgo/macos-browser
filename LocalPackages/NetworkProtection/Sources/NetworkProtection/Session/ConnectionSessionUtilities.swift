//
//  ConnectionSessionUtilities.swift
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

import Foundation
import NetworkExtension

/// These are only usable from the App that owns the tunnel.
///
public class ConnectionSessionUtilities {
    public static func activeSession() async throws -> NETunnelProviderSession? {
        let managers = try await NETunnelProviderManager.loadAllFromPreferences()

        guard let manager = managers.first else {
            // No active connection, this is acceptable
            return nil
        }

        guard let session = manager.connection as? NETunnelProviderSession else {
            // The active connection is not running, so there's no session, this is acceptable
            return nil
        }

        return session
    }

    /// Retrieves a session from a `NEVPNStatusDidChange` notification.
    ///
    public static func session(from notification: Notification) -> NETunnelProviderSession? {
        guard let session = (notification.object as? NETunnelProviderSession),
              session.manager.protocolConfiguration is NETunnelProviderProtocol else {
            return nil
        }

        /// Some situations can cause the connection status in the session's manager to be invalid.
        /// This just means we need to reload the manager from preferences.  That will trigger another status change
        /// notification that will provide a valid connection status.
        guard session.manager.connection.status != .invalid else {
            Task {
                try await session.manager.loadFromPreferences()
            }

            return nil
        }

        return session
    }
}
