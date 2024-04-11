//
//  TransparentProxyControllerPixel.swift
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

extension TransparentProxyController.StartError: CustomNSError {
    public var errorUserInfo: [String: Any] {
        switch self {
        case .failedToLoadConfiguration(let underlyingError),
                .failedToSaveConfiguration(let underlyingError),
                .failedToStartProvider(let underlyingError):
            return [
                NSUnderlyingErrorKey: underlyingError as NSError
            ]
        default:
            return [:]
        }
    }
}

extension TransparentProxyController {

    public enum Event: PixelKitEventV2 {
        case startInitiated
        case startSuccess
        case startFailure(_ error: Error)

        // MARK: - PixelKit.Event

        public var name: String {
            namePrefix + "_" + nameSuffix
        }

        public var parameters: [String: String]? {
            switch self {
            case .startInitiated:
                return nil
            case .startSuccess:
                return nil
            case .startFailure:
                return nil
            }
        }

        // MARK: - PixelKit Support

        private static let pixelNamePrefix = "vpn_proxy_controller"

        private var namePrefix: String {
            Self.pixelNamePrefix
        }

        private var nameSuffix: String {
            switch self {
            case .startInitiated:
                return "start_initiated"
            case .startFailure:
                return "start_failure"
            case .startSuccess:
                return "start_success"
            }
        }

        public var error: Error? {
            switch self {
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
