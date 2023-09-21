//
//  PixelKitEvent.swift
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

import PixelKit

public enum NetworkProtectionPixelKitEvent: PixelKitEvent {
    case networkProtectionSystemExtensionUnknownActivationResult
    case networkProtectionActiveUser

    case networkProtectionTunnelConfigurationNoServerRegistrationInfo
    case networkProtectionTunnelConfigurationCouldNotSelectClosestServer
    case networkProtectionTunnelConfigurationCouldNotGetPeerPublicKey
    case networkProtectionTunnelConfigurationCouldNotGetPeerHostName
    case networkProtectionTunnelConfigurationCouldNotGetInterfaceAddressRange

    case networkProtectionClientFailedToFetchServerList(error: Error?)
    case networkProtectionClientFailedToParseServerListResponse
    case networkProtectionClientFailedToEncodeRegisterKeyRequest
    case networkProtectionClientFailedToFetchRegisteredServers(error: Error?)
    case networkProtectionClientFailedToParseRegisteredServersResponse
    case networkProtectionClientFailedToEncodeRedeemRequest
    case networkProtectionClientInvalidInviteCode
    case networkProtectionClientFailedToRedeemInviteCode(error: Error?)
    case networkProtectionClientFailedToParseRedeemResponse(error: Error)
    case networkProtectionClientInvalidAuthToken

    case networkProtectionServerListStoreFailedToEncodeServerList
    case networkProtectionServerListStoreFailedToDecodeServerList
    case networkProtectionServerListStoreFailedToWriteServerList(error: Error)
    case networkProtectionServerListStoreFailedToReadServerList(error: Error)

    case networkProtectionKeychainErrorFailedToCastKeychainValueToData(field: String)
    case networkProtectionKeychainReadError(field: String, status: Int32)
    case networkProtectionKeychainWriteError(field: String, status: Int32)
    case networkProtectionKeychainDeleteError(status: Int32)

    case networkProtectionNoAuthTokenFoundError

    case networkProtectionRekeyCompleted

    case networkProtectionLatency(ms: Int, server: String, networkType: String)

    case networkProtectionUnhandledError(function: String, line: Int, error: Error)

    public var name: String {
        switch self {
        case .networkProtectionSystemExtensionUnknownActivationResult:
            return "netp_system_extension_unknown_activation_result"

        case .networkProtectionActiveUser:
            return "netp_daily_active"

        case .networkProtectionTunnelConfigurationNoServerRegistrationInfo:
            return "netp_tunnel_config_error_no_server_registration_info"

        case .networkProtectionTunnelConfigurationCouldNotSelectClosestServer:
            return "netp_tunnel_config_error_could_not_select_closest_server"

        case .networkProtectionTunnelConfigurationCouldNotGetPeerPublicKey:
            return "netp_tunnel_config_error_could_not_get_peer_public_key"

        case .networkProtectionTunnelConfigurationCouldNotGetPeerHostName:
            return "netp_tunnel_config_error_could_not_get_peer_host_name"

        case .networkProtectionTunnelConfigurationCouldNotGetInterfaceAddressRange:
            return "netp_tunnel_config_error_could_not_get_interface_address_range"

        case .networkProtectionClientFailedToFetchServerList:
            return "netp_backend_api_error_failed_to_fetch_server_list"

        case .networkProtectionClientFailedToParseServerListResponse:
            return "netp_backend_api_error_parsing_server_list_response_failed"

        case .networkProtectionClientFailedToEncodeRegisterKeyRequest:
            return "netp_backend_api_error_encoding_register_request_body_failed"

        case .networkProtectionClientFailedToFetchRegisteredServers:
            return "netp_backend_api_error_failed_to_fetch_registered_servers"

        case .networkProtectionClientFailedToParseRegisteredServersResponse:
            return "netp_backend_api_error_parsing_device_registration_response_failed"

        case .networkProtectionClientFailedToEncodeRedeemRequest:
            return "netp_backend_api_error_encoding_redeem_request_body_failed"

        case .networkProtectionClientInvalidInviteCode:
            return "netp_backend_api_error_invalid_invite_code"

        case .networkProtectionClientFailedToRedeemInviteCode:
            return "netp_backend_api_error_failed_to_redeem_invite_code"

        case .networkProtectionClientFailedToParseRedeemResponse:
            return "netp_backend_api_error_parsing_redeem_response_failed"

        case .networkProtectionClientInvalidAuthToken:
            return "netp_backend_api_error_invalid_auth_token"

        case .networkProtectionServerListStoreFailedToEncodeServerList:
            return "netp_storage_error_failed_to_encode_server_list"

        case .networkProtectionServerListStoreFailedToDecodeServerList:
            return "netp_storage_error_failed_to_decode_server_list"

        case .networkProtectionServerListStoreFailedToWriteServerList:
            return "netp_storage_error_server_list_file_system_write_failed"

        case .networkProtectionServerListStoreFailedToReadServerList:
            return "netp_storage_error_server_list_file_system_read_failed"

        case .networkProtectionKeychainErrorFailedToCastKeychainValueToData:
            return "netp_keychain_error_failed_to_cast_keychain_value_to_data"

        case .networkProtectionKeychainReadError:
            return "netp_keychain_error_read_failed"

        case .networkProtectionKeychainWriteError:
            return "netp_keychain_error_write_failed"

        case .networkProtectionKeychainDeleteError:
            return "netp_keychain_error_delete_failed"

        case .networkProtectionNoAuthTokenFoundError:
            return "netp_no_auth_token_found_error"

        case .networkProtectionRekeyCompleted:
            return "netp_rekey_completed"

        case .networkProtectionLatency:
            return "netp_latency"

        case .networkProtectionUnhandledError:
            return "netp_unhandled_error"
        }
    }

    public var parameters: [String: String]? {
        switch self {
        case .networkProtectionKeychainErrorFailedToCastKeychainValueToData(let field):
            return [PixelKit.Parameters.keychainFieldName: field]

        case .networkProtectionKeychainReadError(let field, let status):
            return [
                PixelKit.Parameters.keychainFieldName: field,
                PixelKit.Parameters.errorCode: String(status)
            ]

        case .networkProtectionKeychainWriteError(let field, let status):
            return [
                PixelKit.Parameters.keychainFieldName: field,
                PixelKit.Parameters.errorCode: String(status)
            ]

        case .networkProtectionKeychainDeleteError(let status):
            return [
                PixelKit.Parameters.errorCode: String(status)
            ]

        case .networkProtectionServerListStoreFailedToWriteServerList(let error):
            return error.pixelParameters

        case .networkProtectionServerListStoreFailedToReadServerList(let error):
            return error.pixelParameters

        case .networkProtectionClientFailedToFetchServerList(let error):
            return error?.pixelParameters

        case .networkProtectionClientFailedToFetchRegisteredServers(let error):
            return error?.pixelParameters

        case .networkProtectionClientFailedToRedeemInviteCode(error: let error):
            return error?.pixelParameters

        case .networkProtectionUnhandledError(let function, let line, let error):
            var parameters = error.pixelParameters
            parameters[PixelKit.Parameters.function] = function
            parameters[PixelKit.Parameters.line] = String(line)
            return parameters

        case .networkProtectionLatency(ms: let latency, server: let server, networkType: let networkType):
            return [
                PixelKit.Parameters.latency: String(latency),
                PixelKit.Parameters.server: server,
                PixelKit.Parameters.networkType: networkType
            ]

        case .networkProtectionSystemExtensionUnknownActivationResult,
             .networkProtectionTunnelConfigurationNoServerRegistrationInfo,
             .networkProtectionTunnelConfigurationCouldNotSelectClosestServer,
             .networkProtectionTunnelConfigurationCouldNotGetPeerPublicKey,
             .networkProtectionTunnelConfigurationCouldNotGetPeerHostName,
             .networkProtectionTunnelConfigurationCouldNotGetInterfaceAddressRange,
             .networkProtectionClientFailedToParseServerListResponse,
             .networkProtectionClientFailedToEncodeRegisterKeyRequest,
             .networkProtectionClientFailedToParseRegisteredServersResponse,
             .networkProtectionClientFailedToParseRedeemResponse,
             .networkProtectionClientInvalidInviteCode,
             .networkProtectionClientFailedToEncodeRedeemRequest,
             .networkProtectionClientInvalidAuthToken,
             .networkProtectionServerListStoreFailedToEncodeServerList,
             .networkProtectionServerListStoreFailedToDecodeServerList,
             .networkProtectionNoAuthTokenFoundError,
             .networkProtectionRekeyCompleted,
             .networkProtectionActiveUser:

            return nil
        }
    }
}
