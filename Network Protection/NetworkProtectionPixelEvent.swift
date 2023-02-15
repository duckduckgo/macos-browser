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

extension Pixel {
    static func fire(_ event: NetworkProtectionPixelEvent,
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
        
        let appVersion = AppVersion(bundle: NetworkProtectionBundle.mainAppBundle())
        
        Pixel.shared?.fire(pixelNamed: event.name,
                           withAdditionalParameters: newParams,
                           allowedQueryReservedCharacters: allowedQueryReservedCharacters,
                           includeAppVersionParameter: includeAppVersionParameter,
                           withHeaders: APIHeaders(appVersion: appVersion).defaultHeaders,
                           onComplete: onComplete)
    }
}

enum NetworkProtectionPixelEvent {
    case networkProtectionTunnelConfigurationNoServerRegistrationInfo
    case networkProtectionTunnelConfigurationCouldNotSelectClosestServer
    case networkProtectionTunnelConfigurationCouldNotGetPeerPublicKey
    case networkProtectionTunnelConfigurationCouldNotGetPeerHostName
    case networkProtectionTunnelConfigurationCouldNotGetInterfaceAddressRange

    case networkProtectionClientFailedToParseServerListResponse
    case networkProtectionClientFailedToEncodeRegisterKeyRequest
    case networkProtectionClientFailedToParseRegisteredServersResponse

    case networkProtectionServerListStoreFailedToEncodeServerList
    case networkProtectionServerListStoreFailedToWriteServerList(error: Error)
    case networkProtectionServerListStoreFailedToReadServerList(error: Error)

    case networkProtectionKeychainErrorFailedToCastKeychainValueToData(field: String)
    case networkProtectionKeychainReadError(field: String, status: Int32)
    case networkProtectionKeychainWriteError(field: String, status: Int32)
    case networkProtectionKeychainDeleteError(field: String, status: Int32)

    case networkProtectionUnhandledError(function: String, line: Int, error: Error)
    
    var name: String {
        switch self {
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

        case .networkProtectionClientFailedToParseServerListResponse:
            return "m_mac_netp_backend_api_error_parsing_server_list_response_failed"

        case .networkProtectionClientFailedToEncodeRegisterKeyRequest:
            return "m_mac_netp_backend_api_error_encoding_register_request_body_failed"

        case .networkProtectionClientFailedToParseRegisteredServersResponse:
            return "m_mac_netp_backend_api_error_parsing_device_registration_response_failed"

        case .networkProtectionServerListStoreFailedToEncodeServerList:
            return "m_mac_netp_storage_error_failed_to_encode_server_list"

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

        case .networkProtectionKeychainDeleteError(let field, let status):
            return [
                Pixel.Parameters.keychainFieldName: field,
                Pixel.Parameters.errorCode: String(status)
            ]

        case .networkProtectionServerListStoreFailedToWriteServerList(let error):
            return error.pixelParameters

        case .networkProtectionServerListStoreFailedToReadServerList(let error):
            return error.pixelParameters

        case .networkProtectionUnhandledError(let function, let line, let error):
            var parameters = error.pixelParameters
            parameters["function"] = function
            parameters["line"] = String(line)
            return parameters

        case .networkProtectionTunnelConfigurationNoServerRegistrationInfo,
             .networkProtectionTunnelConfigurationCouldNotSelectClosestServer,
             .networkProtectionTunnelConfigurationCouldNotGetPeerPublicKey,
             .networkProtectionTunnelConfigurationCouldNotGetPeerHostName,
             .networkProtectionTunnelConfigurationCouldNotGetInterfaceAddressRange,
             .networkProtectionClientFailedToParseServerListResponse,
             .networkProtectionClientFailedToEncodeRegisterKeyRequest,
             .networkProtectionClientFailedToParseRegisteredServersResponse,
             .networkProtectionServerListStoreFailedToEncodeServerList:

            return nil
        }
    }
}
