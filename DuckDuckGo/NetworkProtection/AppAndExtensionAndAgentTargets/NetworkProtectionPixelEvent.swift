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

import Foundation
import PixelKit
import NetworkProtection
import Configuration

enum NetworkProtectionPixelEvent: PixelKitEventV2 {
    static let vpnErrorDomain = "com.duckduckgo.vpn.errorDomain"

    case networkProtectionActiveUser
    case networkProtectionNewUser

    case networkProtectionControllerStartAttempt
    case networkProtectionControllerStartSuccess
    case networkProtectionControllerStartCancelled
    case networkProtectionControllerStartFailure(_ error: Error)

    case networkProtectionTunnelStartAttempt
    case networkProtectionTunnelStartAttemptOnDemandWithoutAccessToken
    case networkProtectionTunnelStartSuccess
    case networkProtectionTunnelStartFailure(_ error: Error)

    case networkProtectionTunnelStopAttempt
    case networkProtectionTunnelStopSuccess
    case networkProtectionTunnelStopFailure(_ error: Error)

    case networkProtectionTunnelUpdateAttempt
    case networkProtectionTunnelUpdateSuccess
    case networkProtectionTunnelUpdateFailure(_ error: Error)

    case networkProtectionTunnelWakeAttempt
    case networkProtectionTunnelWakeSuccess
    case networkProtectionTunnelWakeFailure(_ error: Error)

    case networkProtectionServerMigrationAttempt
    case networkProtectionServerMigrationSuccess
    case networkProtectionServerMigrationFailure(_ error: Error)

    case networkProtectionEnableAttemptConnecting
    case networkProtectionEnableAttemptSuccess
    case networkProtectionEnableAttemptFailure

    case networkProtectionConnectionTesterFailureDetected(server: String)
    case networkProtectionConnectionTesterFailureRecovered(server: String, failureCount: Int)
    case networkProtectionConnectionTesterExtendedFailureDetected(server: String)
    case networkProtectionConnectionTesterExtendedFailureRecovered(server: String, failureCount: Int)

    case networkProtectionTunnelFailureDetected
    case networkProtectionTunnelFailureRecovered

    case networkProtectionLatency(quality: NetworkProtectionLatencyMonitor.ConnectionQuality)
    case networkProtectionLatencyError

    case networkProtectionTunnelConfigurationNoServerRegistrationInfo
    case networkProtectionTunnelConfigurationCouldNotSelectClosestServer
    case networkProtectionTunnelConfigurationCouldNotGetPeerPublicKey
    case networkProtectionTunnelConfigurationCouldNotGetPeerHostName
    case networkProtectionTunnelConfigurationCouldNotGetInterfaceAddressRange

    case networkProtectionClientFailedToFetchServerList(_ error: Error?)
    case networkProtectionClientFailedToParseServerListResponse
    case networkProtectionClientFailedToEncodeRegisterKeyRequest
    case networkProtectionClientFailedToFetchRegisteredServers(_ error: Error?)
    case networkProtectionClientFailedToParseRegisteredServersResponse
    case networkProtectionClientFailedToFetchLocations(_ error: Error?)
    case networkProtectionClientFailedToParseLocationsResponse(_ error: Error?)
    case networkProtectionClientFailedToFetchServerStatus(_ error: Error?)
    case networkProtectionClientFailedToParseServerStatusResponse(_ error: Error?)
    case networkProtectionClientInvalidAuthToken

    case networkProtectionKeychainErrorFailedToCastKeychainValueToData(field: String)
    case networkProtectionKeychainReadError(field: String, status: Int32)
    case networkProtectionKeychainWriteError(field: String, status: Int32)
    case networkProtectionKeychainUpdateError(field: String, status: Int32)
    case networkProtectionKeychainDeleteError(status: Int32)

    case networkProtectionWireguardErrorCannotLocateTunnelFileDescriptor
    case networkProtectionWireguardErrorInvalidState(reason: String)
    case networkProtectionWireguardErrorFailedDNSResolution
    case networkProtectionWireguardErrorCannotSetNetworkSettings(_ error: Error)
    case networkProtectionWireguardErrorCannotStartWireguardBackend(_ error: Error)
    case networkProtectionWireguardErrorCannotSetWireguardConfig(_ error: Error)

    case networkProtectionNoAuthTokenFoundError

    case networkProtectionRekeyAttempt
    case networkProtectionRekeyCompleted
    case networkProtectionRekeyFailure(_ error: Error)

    case networkProtectionDNSUpdateCustom
    case networkProtectionDNSUpdateDefault

    case networkProtectionSystemExtensionActivationFailure(_ error: Error)

    case networkProtectionConfigurationInvalidPayload(configuration: Configuration)
    case networkProtectionConfigurationErrorLoadingCachedConfig(_ error: Error)
    case networkProtectionConfigurationFailedToParse(_ error: Error)

    case networkProtectionUnhandledError(function: String, line: Int, error: Error)

    /// Name of the pixel event
    /// - Unique pixels must end with `_u`
    /// - Daily pixels will automatically have `_d` or `_c` appended to their names
    var name: String {
        switch self {

        case .networkProtectionActiveUser:
            return "netp_daily_active"

        case .networkProtectionNewUser:
            return "netp_daily_active_u"

        case .networkProtectionControllerStartAttempt:
            return "netp_controller_start_attempt"

        case .networkProtectionControllerStartSuccess:
            return "netp_controller_start_success"

        case .networkProtectionControllerStartCancelled:
            return "netp_controller_start_cancelled"

        case .networkProtectionControllerStartFailure:
            return "netp_controller_start_failure"

        case .networkProtectionTunnelStartAttempt:
            return "netp_tunnel_start_attempt"

        case .networkProtectionTunnelStartAttemptOnDemandWithoutAccessToken:
            return "netp_tunnel_start_attempt_on_demand_without_access_token"

        case .networkProtectionTunnelStartSuccess:
            return "netp_tunnel_start_success"

        case .networkProtectionTunnelStartFailure:
            return "netp_tunnel_start_failure"

        case .networkProtectionTunnelStopAttempt:
            return "netp_tunnel_stop_attempt"

        case .networkProtectionTunnelStopSuccess:
            return "netp_tunnel_stop_success"

        case .networkProtectionTunnelStopFailure:
            return "netp_tunnel_stop_failure"

        case .networkProtectionTunnelUpdateAttempt:
            return "netp_tunnel_update_attempt"

        case .networkProtectionTunnelUpdateSuccess:
            return "netp_tunnel_update_success"

        case .networkProtectionTunnelUpdateFailure:
            return "netp_tunnel_update_failure"

        case .networkProtectionTunnelWakeAttempt:
            return "netp_tunnel_wake_attempt"

        case .networkProtectionTunnelWakeSuccess:
            return "netp_tunnel_wake_success"

        case .networkProtectionTunnelWakeFailure:
            return "netp_tunnel_wake_failure"

        case .networkProtectionEnableAttemptConnecting:
            return "netp_ev_enable_attempt"

        case .networkProtectionEnableAttemptSuccess:
            return "netp_ev_enable_attempt_success"

        case .networkProtectionEnableAttemptFailure:
            return "netp_ev_enable_attempt_failure"

        case .networkProtectionConnectionTesterFailureDetected:
            return "netp_connection_tester_failure"

        case .networkProtectionConnectionTesterFailureRecovered:
            return "netp_connection_tester_failure_recovered"

        case .networkProtectionConnectionTesterExtendedFailureDetected:
            return "netp_connection_tester_extended_failure"

        case .networkProtectionConnectionTesterExtendedFailureRecovered:
            return "netp_connection_tester_extended_failure_recovered"

        case .networkProtectionTunnelFailureDetected:
            return "netp_ev_tunnel_failure"

        case .networkProtectionTunnelFailureRecovered:
            return "netp_ev_tunnel_failure_recovered"

        case .networkProtectionLatency(let quality):
            return "netp_ev_\(quality.rawValue)_latency"

        case .networkProtectionLatencyError:
            return "netp_ev_latency_error"

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

        case .networkProtectionClientFailedToFetchLocations:
            return "netp_backend_api_error_failed_to_fetch_location_list"

        case .networkProtectionClientFailedToParseLocationsResponse:
            return "netp_backend_api_error_parsing_location_list_response_failed"

        case .networkProtectionClientInvalidAuthToken:
            return "netp_backend_api_error_invalid_auth_token"

        case .networkProtectionKeychainErrorFailedToCastKeychainValueToData:
            return "netp_keychain_error_failed_to_cast_keychain_value_to_data"

        case .networkProtectionKeychainReadError:
            return "netp_keychain_error_read_failed"

        case .networkProtectionKeychainWriteError:
            return "netp_keychain_error_write_failed"

        case .networkProtectionKeychainUpdateError:
            return "netp_keychain_error_update_failed"

        case .networkProtectionKeychainDeleteError:
            return "netp_keychain_error_delete_failed"

        case .networkProtectionWireguardErrorCannotLocateTunnelFileDescriptor:
            return "netp_wireguard_error_cannot_locate_tunnel_file_descriptor"

        case .networkProtectionWireguardErrorInvalidState:
            return "netp_wireguard_error_invalid_state"

        case .networkProtectionWireguardErrorFailedDNSResolution:
            return "netp_wireguard_error_failed_dns_resolution"

        case .networkProtectionWireguardErrorCannotSetNetworkSettings:
            return "netp_wireguard_error_cannot_set_network_settings"

        case .networkProtectionWireguardErrorCannotStartWireguardBackend:
            return "netp_wireguard_error_cannot_start_wireguard_backend"

        case .networkProtectionWireguardErrorCannotSetWireguardConfig:
            return "netp_wireguard_error_cannot_set_wireguard_config"

        case .networkProtectionNoAuthTokenFoundError:
            return "netp_no_auth_token_found_error"

        case .networkProtectionRekeyAttempt:
            return "netp_rekey_attempt"

        case .networkProtectionRekeyCompleted:
            return "netp_rekey_completed"

        case .networkProtectionRekeyFailure:
            return "netp_rekey_failure"

        case .networkProtectionSystemExtensionActivationFailure:
            return "netp_system_extension_activation_failure"

        case .networkProtectionClientFailedToFetchServerStatus:
            return "netp_server_migration_failed_to_fetch_status"

        case .networkProtectionClientFailedToParseServerStatusResponse:
            return "netp_server_migration_failed_to_parse_response"

        case .networkProtectionServerMigrationAttempt:
            return "netp_ev_server_migration_attempt"

        case .networkProtectionServerMigrationFailure:
            return "netp_ev_server_migration_attempt_failure"

        case .networkProtectionServerMigrationSuccess:
            return "netp_ev_server_migration_attempt_success"

        case .networkProtectionDNSUpdateCustom:
            return "netp_ev_update_dns_custom"

        case .networkProtectionDNSUpdateDefault:
            return "netp_ev_update_dns_default"

        case .networkProtectionConfigurationInvalidPayload(let config):
            return "netp_ev_configuration_\(config.rawValue)_invalid_payload".lowercased()

        case .networkProtectionConfigurationErrorLoadingCachedConfig:
            return "netp_ev_configuration_error_loading_cached_config"

        case .networkProtectionConfigurationFailedToParse:
            return "netp_ev_configuration_failed_to_parse"

        case .networkProtectionUnhandledError:
            return "netp_unhandled_error"
        }
    }

    var parameters: [String: String]? {
        switch self {
        case .networkProtectionConnectionTesterFailureDetected(let server),
                .networkProtectionConnectionTesterExtendedFailureDetected(let server):
            return [PixelKit.Parameters.server: server]
        case .networkProtectionConnectionTesterFailureRecovered(let server, let failureCount),
                .networkProtectionConnectionTesterExtendedFailureRecovered(let server, let failureCount):
            return [
                PixelKit.Parameters.server: server,
                PixelKit.Parameters.count: String(failureCount)
            ]
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
        case .networkProtectionKeychainUpdateError(let field, let status):
            return [
                PixelKit.Parameters.keychainFieldName: field,
                PixelKit.Parameters.errorCode: String(status)
            ]
        case .networkProtectionKeychainDeleteError(let status):
            return [PixelKit.Parameters.errorCode: String(status)]
        case .networkProtectionClientFailedToFetchServerList(let error):
            return error?.pixelParameters
        case .networkProtectionClientFailedToFetchRegisteredServers(let error):
            return error?.pixelParameters
        case .networkProtectionClientFailedToFetchLocations(let error):
            return error?.pixelParameters
        case .networkProtectionClientFailedToParseLocationsResponse(let error):
            return error?.pixelParameters
        case .networkProtectionUnhandledError(let function, let line, let error):
            var parameters = error.pixelParameters
            parameters[PixelKit.Parameters.function] = function
            parameters[PixelKit.Parameters.line] = String(line)
            return parameters
        case .networkProtectionWireguardErrorCannotSetNetworkSettings(let error):
            return error.pixelParameters
        case .networkProtectionWireguardErrorCannotStartWireguardBackend(let error):
            return error.pixelParameters
        case .networkProtectionWireguardErrorCannotSetWireguardConfig(let error):
            return error.pixelParameters
        case .networkProtectionClientFailedToFetchServerStatus(let error):
            return error?.pixelParameters
        case .networkProtectionClientFailedToParseServerStatusResponse(let error):
            return error?.pixelParameters
        case .networkProtectionWireguardErrorInvalidState(reason: let reason):
            return [PixelKit.Parameters.reason: reason]
        case .networkProtectionServerMigrationFailure:
            return error?.pixelParameters
        case .networkProtectionConfigurationErrorLoadingCachedConfig(let error):
            return error.pixelParameters
        case .networkProtectionConfigurationFailedToParse(let error):
            return error.pixelParameters
        case .networkProtectionActiveUser,
                .networkProtectionNewUser,
                .networkProtectionControllerStartAttempt,
                .networkProtectionControllerStartSuccess,
                .networkProtectionControllerStartCancelled,
                .networkProtectionControllerStartFailure,
                .networkProtectionTunnelStartAttempt,
                .networkProtectionTunnelStartAttemptOnDemandWithoutAccessToken,
                .networkProtectionTunnelStartSuccess,
                .networkProtectionTunnelStartFailure,
                .networkProtectionTunnelStopAttempt,
                .networkProtectionTunnelStopSuccess,
                .networkProtectionTunnelStopFailure,
                .networkProtectionTunnelUpdateAttempt,
                .networkProtectionTunnelUpdateSuccess,
                .networkProtectionTunnelUpdateFailure,
                .networkProtectionTunnelWakeAttempt,
                .networkProtectionTunnelWakeSuccess,
                .networkProtectionTunnelWakeFailure,
                .networkProtectionEnableAttemptConnecting,
                .networkProtectionEnableAttemptSuccess,
                .networkProtectionEnableAttemptFailure,
                .networkProtectionTunnelFailureDetected,
                .networkProtectionTunnelFailureRecovered,
                .networkProtectionLatency,
                .networkProtectionLatencyError,
                .networkProtectionTunnelConfigurationNoServerRegistrationInfo,
                .networkProtectionTunnelConfigurationCouldNotSelectClosestServer,
                .networkProtectionTunnelConfigurationCouldNotGetPeerPublicKey,
                .networkProtectionTunnelConfigurationCouldNotGetPeerHostName,
                .networkProtectionTunnelConfigurationCouldNotGetInterfaceAddressRange,
                .networkProtectionClientFailedToParseServerListResponse,
                .networkProtectionClientFailedToEncodeRegisterKeyRequest,
                .networkProtectionClientFailedToParseRegisteredServersResponse,
                .networkProtectionClientInvalidAuthToken,
                .networkProtectionWireguardErrorCannotLocateTunnelFileDescriptor,
                .networkProtectionWireguardErrorFailedDNSResolution,
                .networkProtectionNoAuthTokenFoundError,
                .networkProtectionRekeyAttempt,
                .networkProtectionRekeyCompleted,
                .networkProtectionRekeyFailure,
                .networkProtectionSystemExtensionActivationFailure,
                .networkProtectionServerMigrationAttempt,
                .networkProtectionServerMigrationSuccess,
                .networkProtectionDNSUpdateCustom,
                .networkProtectionDNSUpdateDefault,
                .networkProtectionConfigurationInvalidPayload:
            return nil
        }
    }

    var error: (any Error)? {
        switch self {
        case .networkProtectionClientFailedToFetchLocations(let error),
                .networkProtectionClientFailedToParseLocationsResponse(let error),
                .networkProtectionClientFailedToFetchServerList(let error),
                .networkProtectionClientFailedToFetchRegisteredServers(let error),
                .networkProtectionClientFailedToFetchServerStatus(let error),
                .networkProtectionClientFailedToParseServerStatusResponse(let error):
            return error
        case .networkProtectionControllerStartFailure(let error),
                .networkProtectionTunnelStartFailure(let error),
                .networkProtectionTunnelStopFailure(let error),
                .networkProtectionTunnelUpdateFailure(let error),
                .networkProtectionTunnelWakeFailure(let error),
                .networkProtectionWireguardErrorCannotSetNetworkSettings(let error),
                .networkProtectionWireguardErrorCannotStartWireguardBackend(let error),
                .networkProtectionWireguardErrorCannotSetWireguardConfig(let error),
                .networkProtectionRekeyFailure(let error),
                .networkProtectionUnhandledError(_, _, let error),
                .networkProtectionSystemExtensionActivationFailure(let error),
                .networkProtectionServerMigrationFailure(let error),
                .networkProtectionConfigurationErrorLoadingCachedConfig(let error),
                .networkProtectionConfigurationFailedToParse(let error):
            return error
        case .networkProtectionActiveUser,
                .networkProtectionNewUser,
                .networkProtectionControllerStartAttempt,
                .networkProtectionControllerStartSuccess,
                .networkProtectionControllerStartCancelled,
                .networkProtectionTunnelStartAttempt,
                .networkProtectionTunnelStartAttemptOnDemandWithoutAccessToken,
                .networkProtectionTunnelStartSuccess,
                .networkProtectionTunnelStopAttempt,
                .networkProtectionTunnelStopSuccess,
                .networkProtectionTunnelUpdateAttempt,
                .networkProtectionTunnelUpdateSuccess,
                .networkProtectionTunnelWakeAttempt,
                .networkProtectionTunnelWakeSuccess,
                .networkProtectionEnableAttemptConnecting,
                .networkProtectionEnableAttemptSuccess,
                .networkProtectionEnableAttemptFailure,
                .networkProtectionConnectionTesterFailureDetected,
                .networkProtectionConnectionTesterFailureRecovered,
                .networkProtectionConnectionTesterExtendedFailureDetected,
                .networkProtectionConnectionTesterExtendedFailureRecovered,
                .networkProtectionTunnelFailureDetected,
                .networkProtectionTunnelFailureRecovered,
                .networkProtectionLatency,
                .networkProtectionLatencyError,
                .networkProtectionTunnelConfigurationNoServerRegistrationInfo,
                .networkProtectionTunnelConfigurationCouldNotSelectClosestServer,
                .networkProtectionTunnelConfigurationCouldNotGetPeerPublicKey,
                .networkProtectionTunnelConfigurationCouldNotGetPeerHostName,
                .networkProtectionTunnelConfigurationCouldNotGetInterfaceAddressRange,
                .networkProtectionClientFailedToParseServerListResponse,
                .networkProtectionClientFailedToEncodeRegisterKeyRequest,
                .networkProtectionClientFailedToParseRegisteredServersResponse,
                .networkProtectionClientInvalidAuthToken,
                .networkProtectionKeychainErrorFailedToCastKeychainValueToData,
                .networkProtectionKeychainReadError,
                .networkProtectionKeychainWriteError,
                .networkProtectionKeychainUpdateError,
                .networkProtectionKeychainDeleteError,
                .networkProtectionWireguardErrorCannotLocateTunnelFileDescriptor,
                .networkProtectionWireguardErrorInvalidState,
                .networkProtectionWireguardErrorFailedDNSResolution,
                .networkProtectionNoAuthTokenFoundError,
                .networkProtectionRekeyAttempt,
                .networkProtectionRekeyCompleted,
                .networkProtectionServerMigrationAttempt,
                .networkProtectionServerMigrationSuccess,
                .networkProtectionDNSUpdateCustom,
                .networkProtectionDNSUpdateDefault,
                .networkProtectionConfigurationInvalidPayload:
            return nil
        }
    }
}
