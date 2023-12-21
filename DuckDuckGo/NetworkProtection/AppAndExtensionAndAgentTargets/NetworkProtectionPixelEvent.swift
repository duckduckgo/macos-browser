//
//  NetworkProtectionPixelEvent.swift
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
import PixelKit
import NetworkProtection

enum NetworkProtectionPixelEvent: PixelKitEvent {

    case networkProtectionActiveUser
    case networkProtectionNewUser

    case networkProtectionStartFailed

    case networkProtectionEnableAttemptConnecting
    case networkProtectionEnableAttemptSuccess
    case networkProtectionEnableAttemptFailure

    case networkProtectionTunnelFailureDetected
    case networkProtectionTunnelFailureRecovered

    case networkProtectionLatency(quality: NetworkProtectionLatencyMonitor.ConnectionQuality)
    case networkProtectionLatencyError

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

    case networkProtectionWireguardErrorCannotLocateTunnelFileDescriptor
    case networkProtectionWireguardErrorInvalidState(reason: String)
    case networkProtectionWireguardErrorFailedDNSResolution
    case networkProtectionWireguardErrorCannotSetNetworkSettings(error: Error)
    case networkProtectionWireguardErrorCannotStartWireguardBackend(code: Int32)

    case networkProtectionNoAuthTokenFoundError

    case networkProtectionRekeyCompleted

    case networkProtectionSystemExtensionActivationFailure

    case networkProtectionUnhandledError(function: String, line: Int, error: Error)

    /// Name of the pixel event
    /// - Unique pixels must end with `_u`
    /// - Daily pixels will automatically have `_d` or `_c` appended to their names
    var name: String {
        switch self {

        case .networkProtectionActiveUser:
            return "m_mac_netp_daily_active"

        case .networkProtectionNewUser:
            return "m_mac_netp_daily_active_u"

        case .networkProtectionStartFailed:
            return "m_mac_netp_start_failed"

        case .networkProtectionEnableAttemptConnecting:
            return "m_mac_netp_ev_enable_attempt"

        case .networkProtectionEnableAttemptSuccess:
            return "m_mac_netp_ev_enable_attempt_success"

        case .networkProtectionEnableAttemptFailure:
            return "m_mac_netp_ev_enable_attempt_failure"

        case .networkProtectionTunnelFailureDetected:
            return "m_mac_netp_ev_tunnel_failure"

        case .networkProtectionTunnelFailureRecovered:
            return "m_mac_netp_ev_tunnel_failure_recovered"

        case .networkProtectionLatency(let quality):
            return "m_mac_netp_ev_\(quality.rawValue)_latency"

        case .networkProtectionLatencyError:
            return "m_mac_netp_ev_latency_error"

        case .networkProtectionTunnelConfigurationNoServerRegistrationInfo:
            return "m_mac_netp_tunnel_config_error_no_server_registration_info"

        case .networkProtectionTunnelConfigurationCouldNotSelectClosestServer:
            return "m_mac_netp_tunnel_config_error_could_not_select_closest_server"

        case .networkProtectionTunnelConfigurationCouldNotGetPeerPublicKey:
            return "m_mac_netp_tunnel_config_error_could_not_get_peer_public_key"

        case .networkProtectionTunnelConfigurationCouldNotGetPeerHostName:
            return "m_mac_netp_tunnel_config_error_could_not_get_peer_host_name"

        case .networkProtectionTunnelConfigurationCouldNotGetInterfaceAddressRange:
            return "m_mac_netp_tunnel_config_error_could_not_get_interface_address_range"

        case .networkProtectionClientFailedToFetchServerList:
            return "m_mac_netp_backend_api_error_failed_to_fetch_server_list"

        case .networkProtectionClientFailedToParseServerListResponse:
            return "m_mac_netp_backend_api_error_parsing_server_list_response_failed"

        case .networkProtectionClientFailedToEncodeRegisterKeyRequest:
            return "m_mac_netp_backend_api_error_encoding_register_request_body_failed"

        case .networkProtectionClientFailedToFetchRegisteredServers:
            return "m_mac_netp_backend_api_error_failed_to_fetch_registered_servers"

        case .networkProtectionClientFailedToParseRegisteredServersResponse:
            return "m_mac_netp_backend_api_error_parsing_device_registration_response_failed"

        case .networkProtectionClientFailedToEncodeRedeemRequest:
            return "m_mac_netp_backend_api_error_encoding_redeem_request_body_failed"

        case .networkProtectionClientInvalidInviteCode:
            return "m_mac_netp_backend_api_error_invalid_invite_code"

        case .networkProtectionClientFailedToRedeemInviteCode:
            return "m_mac_netp_backend_api_error_failed_to_redeem_invite_code"

        case .networkProtectionClientFailedToParseRedeemResponse:
            return "m_mac_netp_backend_api_error_parsing_redeem_response_failed"

        case .networkProtectionClientInvalidAuthToken:
            return "m_mac_netp_backend_api_error_invalid_auth_token"

        case .networkProtectionServerListStoreFailedToEncodeServerList:
            return "m_mac_netp_storage_error_failed_to_encode_server_list"

        case .networkProtectionServerListStoreFailedToDecodeServerList:
            return "m_mac_netp_storage_error_failed_to_decode_server_list"

        case .networkProtectionServerListStoreFailedToWriteServerList:
            return "m_mac_netp_storage_error_server_list_file_system_write_failed"

        case .networkProtectionServerListStoreFailedToReadServerList:
            return "m_mac_netp_storage_error_server_list_file_system_read_failed"

        case .networkProtectionKeychainErrorFailedToCastKeychainValueToData:
            return "m_mac_netp_keychain_error_failed_to_cast_keychain_value_to_data"

        case .networkProtectionKeychainReadError:
            return "m_mac_netp_keychain_error_read_failed"

        case .networkProtectionKeychainWriteError:
            return "m_mac_netp_keychain_error_write_failed"

        case .networkProtectionKeychainDeleteError:
            return "m_mac_netp_keychain_error_delete_failed"

        case .networkProtectionWireguardErrorCannotLocateTunnelFileDescriptor:
            return "m_mac_netp_wireguard_error_cannot_locate_tunnel_file_descriptor"

        case .networkProtectionWireguardErrorInvalidState:
            return "m_mac_netp_wireguard_error_invalid_state"

        case .networkProtectionWireguardErrorFailedDNSResolution:
            return "m_mac_netp_wireguard_error_failed_dns_resolution"

        case .networkProtectionWireguardErrorCannotSetNetworkSettings:
            return "m_mac_netp_wireguard_error_cannot_set_network_settings"

        case .networkProtectionWireguardErrorCannotStartWireguardBackend:
            return "m_mac_netp_wireguard_error_cannot_start_wireguard_backend"

        case .networkProtectionNoAuthTokenFoundError:
            return "m_mac_netp_no_auth_token_found_error"

        case .networkProtectionRekeyCompleted:
            return "m_mac_netp_rekey_completed"

        case .networkProtectionSystemExtensionActivationFailure:
            return "m_mac_netp_system_extension_activation_failure"

        case .networkProtectionUnhandledError:
            return "m_mac_netp_unhandled_error"
        }
    }

    var parameters: [String: String]? {
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

        case .networkProtectionWireguardErrorCannotSetNetworkSettings(error: let error):
            return error.pixelParameters

        case .networkProtectionWireguardErrorCannotStartWireguardBackend(code: let code):
            return [
                PixelKit.Parameters.errorCode: String(code)
            ]

        case .networkProtectionWireguardErrorInvalidState(reason: let reason):
            return [
                PixelKit.Parameters.reason: reason
            ]

        case .networkProtectionTunnelConfigurationNoServerRegistrationInfo,
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
             .networkProtectionWireguardErrorCannotLocateTunnelFileDescriptor,
             .networkProtectionWireguardErrorFailedDNSResolution,
             .networkProtectionSystemExtensionActivationFailure,
             .networkProtectionActiveUser,
             .networkProtectionNewUser,
             .networkProtectionEnableAttemptConnecting,
             .networkProtectionEnableAttemptSuccess,
             .networkProtectionEnableAttemptFailure,
             .networkProtectionTunnelFailureDetected,
             .networkProtectionTunnelFailureRecovered,
             .networkProtectionLatency,
             .networkProtectionLatencyError,
             .networkProtectionStartFailed:

            return nil
        }
    }
}

#endif
