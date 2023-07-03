//
//  NetworkProtectionDeviceManager+EventMapping.swift
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

#if NETWORK_PROTECTION

import Foundation
import NetworkProtection
import Common

extension EventMapping where Event == NetworkProtectionError {
    static var networkProtectionAppDebugEvents: EventMapping<NetworkProtectionError> = .init { event, _, _, _ in

        let domainEvent: Pixel.Event.Debug

        switch event {
        case .failedToEncodeRedeemRequest:
            domainEvent = .networkProtectionClientFailedToEncodeRedeemRequest
        case .invalidInviteCode:
            domainEvent = .networkProtectionClientInvalidInviteCode
        case .failedToRedeemInviteCode(let error):
            domainEvent = .networkProtectionClientFailedToRedeemInviteCode(error: error)
        case .failedToParseRedeemResponse(let error):
            domainEvent = .networkProtectionClientFailedToParseRedeemResponse(error: error)
        case .invalidAuthToken:
            domainEvent = .networkProtectionClientInvalidAuthToken
        case .failedToCastKeychainValueToData(field: let field):
            domainEvent = .networkProtectionKeychainErrorFailedToCastKeychainValueToData(field: field)
        case .keychainReadError(field: let field, status: let status):
            domainEvent = .networkProtectionKeychainReadError(field: field, status: status)
        case .keychainWriteError(field: let field, status: let status):
            domainEvent = .networkProtectionKeychainWriteError(field: field, status: status)
        case .keychainDeleteError(status: let status):
            domainEvent = .networkProtectionKeychainDeleteError(status: status)
        case .noAuthTokenFound:
            domainEvent = .networkProtectionNoAuthTokenFoundError
        case
                .noServerRegistrationInfo,
                .couldNotSelectClosestServer,
                .couldNotGetPeerPublicKey,
                .couldNotGetPeerHostName,
                .couldNotGetInterfaceAddressRange,
                .failedToEncodeRegisterKeyRequest,
                .noServerListFound,
                .serverListInconsistency,
                .failedToFetchRegisteredServers,
                .failedToFetchServerList,
                .failedToParseServerListResponse,
                .failedToParseRegisteredServersResponse,
                .failedToEncodeServerList,
                .failedToDecodeServerList,
                .failedToWriteServerList,
                .couldNotCreateServerListDirectory,
                .failedToReadServerList:
            domainEvent = .networkProtectionUnhandledError(function: #function, line: #line, error: event)
            return
        case .unhandledError(function: let function, line: let line, error: let error):
            domainEvent = .networkProtectionUnhandledError(function: function, line: line, error: error)

            return
        }
        Pixel.fire(.debug(event: domainEvent))
    }
}

#endif
