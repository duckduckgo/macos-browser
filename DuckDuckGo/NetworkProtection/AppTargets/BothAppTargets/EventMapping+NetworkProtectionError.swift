//
//  EventMapping+NetworkProtectionError.swift
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
import PixelKit

extension EventMapping where Event == NetworkProtectionError {
    static var networkProtectionAppDebugEvents: EventMapping<NetworkProtectionError> = .init { event, _, _, _ in
        let domainEvent: NetworkProtectionPixelEvent
        let frequency: PixelKit.Frequency

        switch event {
        case .invalidAuthToken:
            domainEvent = .networkProtectionClientInvalidAuthToken
            frequency = .standard
        case .failedToCastKeychainValueToData(field: let field):
            domainEvent = .networkProtectionKeychainErrorFailedToCastKeychainValueToData(field: field)
            frequency = .standard
        case .keychainReadError(field: let field, status: let status):
            domainEvent = .networkProtectionKeychainReadError(field: field, status: status)
            frequency = .standard
        case .keychainWriteError(field: let field, status: let status):
            domainEvent = .networkProtectionKeychainWriteError(field: field, status: status)
            frequency = .standard
        case .keychainUpdateError(field: let field, status: let status):
            domainEvent = .networkProtectionKeychainUpdateError(field: field, status: status)
            frequency = .standard
        case .keychainDeleteError(status: let status):
            domainEvent = .networkProtectionKeychainDeleteError(status: status)
            frequency = .standard
        case .noAuthTokenFound:
            domainEvent = .networkProtectionNoAuthTokenFoundError
            frequency = .standard
        case .failedToFetchLocationList(let error):
            domainEvent = .networkProtectionClientFailedToFetchLocations(error)
            frequency = .legacyDailyAndCount
        case .failedToParseLocationListResponse(let error):
            domainEvent = .networkProtectionClientFailedToParseLocationsResponse(error)
            frequency = .legacyDailyAndCount
        case .noServerRegistrationInfo,
                .couldNotSelectClosestServer,
                .couldNotGetPeerPublicKey,
                .couldNotGetPeerHostName,
                .couldNotGetInterfaceAddressRange,
                .failedToEncodeRegisterKeyRequest,
                .serverListInconsistency,
                .failedToFetchRegisteredServers,
                .failedToFetchServerList,
                .failedToParseServerListResponse,
                .failedToParseRegisteredServersResponse,
                .wireGuardCannotLocateTunnelFileDescriptor,
                .wireGuardInvalidState,
                .wireGuardDnsResolution,
                .wireGuardSetNetworkSettings,
                .startWireGuardBackend,
                .setWireguardConfig,
                .failedToFetchServerStatus,
                .failedToParseServerStatusResponse:
            domainEvent = .networkProtectionUnhandledError(function: #function, line: #line, error: event)
            frequency = .standard
            return
        case .unhandledError(function: let function, line: let line, error: let error):
            domainEvent = .networkProtectionUnhandledError(function: function, line: line, error: error)
            frequency = .standard
            return
        case .vpnAccessRevoked:
            return
        }

        let debugEvent = DebugEvent(eventType: .custom(domainEvent))
        PixelKit.fire(debugEvent, frequency: .standard, includeAppVersionParameter: true)
    }
}
