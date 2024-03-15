//
//  TransparentProxyProviderPixel.swift
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

extension TransparentProxyProvider.StartError: ErrorWithPixelParameters {
    public var errorParameters: [String: String] {
        switch self {
        case .failedToUpdateNetworkSettings(let underlyingError):
            return [
                PixelKit.Parameters.underlyingErrorCode: "\((underlyingError as NSError).code)",
                PixelKit.Parameters.underlyingErrorDomain: (underlyingError as NSError).domain,
            ]
        default:
            return [:]
        }
    }
}

extension TransparentProxyProvider {

    public enum Event: PixelKitEventV2 {
        case failedToUpdateNetworkSettings(_ error: Error)
        case startInitiated
        case startSuccess
        case startFailure(_ error: Error)

        private static let pixelNamePrefix = "vpn_proxy_provider"

        private var namePrefix: String {
            Self.pixelNamePrefix
        }

        private var namePostfix: String {
            switch self {
            case .failedToUpdateNetworkSettings:
                return "failed_to_update_network_settings"
            case .startFailure:
                return "start_failure"
            case .startInitiated:
                return "start_initiated"
            case .startSuccess:
                return "start_success"
            }
        }

        public var name: String {
            namePrefix + "_" + namePostfix
        }

        public var parameters: [String: String]? {
            switch self {
            case.failedToUpdateNetworkSettings:
                return nil
            case .startFailure:
                return nil
            case .startInitiated:
                return nil
            case .startSuccess:
                return nil
            }
        }

        public var error: Error? {
            switch self {
            case .failedToUpdateNetworkSettings(let error):
                return error
            case .startInitiated:
                return nil
            case .startFailure(let error):
                return error
            case .startSuccess:
                return nil
            }
        }
    }
}
