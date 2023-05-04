//
//  NetworkProtectionPixel.swift
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

extension Pixel {

    enum Parameters {
        static let duration = "duration"
        static let test = "test"
        static let appVersion = "appVersion"

        static let keychainFieldName = "fieldName"
        static let errorCode = "e"
        static let errorDesc = "d"
        static let errorCount = "c"

        static let function = "function"
        static let line = "line"

        static let latency = "latency"
        static let server = "server"
        static let networkType = "net_type"
    }

    enum Values {
        static let test = "1"
    }
}

extension Pixel {
    static func fire(_ event: NetworkProtectionPixelEvent,
                     frequency: PixelFrequency,
                     withAdditionalParameters parameters: [String: String]? = nil,
                     allowedQueryReservedCharacters: CharacterSet? = nil,
                     includeAppVersionParameter: Bool = true,
                     onComplete: @escaping (Error?) -> Void = {_ in }) {
        let newParams: [String: String]?
        switch (event.parameters, parameters) {
        case (.some(let parameters), .none):
            newParams = parameters
        case (.none, .some(let parameters)):
            newParams = parameters
        case (.some(let params1), .some(let params2)):
            newParams = params1.merging(params2) { $1 }
        case (.none, .none):
            newParams = nil
        }

        Pixel.shared?.fire(pixelNamed: event.name,
                           frequency: frequency,
                           withAdditionalParameters: newParams,
                           allowedQueryReservedCharacters: allowedQueryReservedCharacters,
                           includeAppVersionParameter: includeAppVersionParameter,
                           onComplete: onComplete)
    }
}

enum NetworkProtectionPixelEvent {
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

    case networkProtectionLatency(ms: Int, server: String, networkType: NetworkConnectionType)

    case networkProtectionUnhandledError(function: String, line: Int, error: Error)

    var name: String {
        switch self {
        case .networkProtectionActiveUser:
            return "m_mac_netp_daily_active"

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

        case .networkProtectionNoAuthTokenFoundError:
            return "m_mac_netp_no_auth_token_found_error"

        case .networkProtectionRekeyCompleted:
            return "m_mac_netp_rekey_completed"

        case .networkProtectionLatency:
            return "m_mac_netp_latency"
        case .networkProtectionUnhandledError:
            return "m_mac_netp_unhandled_error"
        }
    }

    var parameters: [String: String]? {
        switch self {
        case .networkProtectionKeychainErrorFailedToCastKeychainValueToData(let field):
            return [Pixel.Parameters.keychainFieldName: field]

        case .networkProtectionKeychainReadError(let field, let status):
            return [
                Pixel.Parameters.keychainFieldName: field,
                Pixel.Parameters.errorCode: String(status)
            ]

        case .networkProtectionKeychainWriteError(let field, let status):
            return [
                Pixel.Parameters.keychainFieldName: field,
                Pixel.Parameters.errorCode: String(status)
            ]

        case .networkProtectionKeychainDeleteError(let status):
            return [
                Pixel.Parameters.errorCode: String(status)
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
            parameters[Pixel.Parameters.function] = function
            parameters[Pixel.Parameters.line] = String(line)
            return parameters

        case .networkProtectionLatency(ms: let latency, server: let server, networkType: let networkType):
            return [
                Pixel.Parameters.latency: String(latency),
                Pixel.Parameters.server: server,
                Pixel.Parameters.networkType: networkType.description
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
             .networkProtectionActiveUser:

            return nil
        }
    }
}
