//
//  TransparentProxyControllerPixelTests.swift
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
@testable import NetworkProtectionProxy
import PixelKit
import PixelKitTestingUtilities
import XCTest

extension TransparentProxyController.Event: Hashable {
    public static func == (lhs: NetworkProtectionProxy.TransparentProxyController.Event, rhs: NetworkProtectionProxy.TransparentProxyController.Event) -> Bool {

        lhs.name == rhs.name && lhs.parameters == rhs.parameters
    }

    public func hash(into hasher: inout Hasher) {
        name.hash(into: &hasher)
        parameters.hash(into: &hasher)
    }
}

extension TransparentProxyController.StartError: Hashable {
    public static func == (lhs: NetworkProtectionProxy.TransparentProxyController.StartError, rhs: NetworkProtectionProxy.TransparentProxyController.StartError) -> Bool {

        let lhs = lhs as NSError
        let rhs = rhs as NSError

        return lhs.code == rhs.code && lhs.domain == rhs.domain
    }

    public func hash(into hasher: inout Hasher) {
        (self as NSError).hash(into: &hasher)
        (underlyingError as? NSError)?.hash(into: &hasher)
    }
}

final class TransparentProxyControllerPixelTests: XCTestCase {

    static let startFailureFullPixelName = "m_mac_vpn_proxy_controller_start_failure"
    static let startInitiatedFullPixelName = "m_mac_vpn_proxy_controller_start_initiated"
    static let startSuccessFullPixelName = "m_mac_vpn_proxy_controller_start_success"

    enum TestError: CustomNSError {
        case testError

        static let underlyingError = NSError(domain: "test", code: 1)

        public var errorUserInfo: [String: Any] {
            switch self {
            case .testError(let underlyingError):
                return [
                    NSUnderlyingErrorKey: underlyingError as NSError
                ]
            default:
                return [:]
            }
        }
    }

    // MARK: - Test Firing Pixels

    func testFiringPixelsWithoutParameters() {
        let tests: [TransparentProxyController.Event: PixelFireExpectations] = [
            .startInitiated: PixelFireExpectations(pixelName: Self.startInitiatedFullPixelName),
            .startSuccess: PixelFireExpectations(pixelName: Self.startSuccessFullPixelName)
        ]

        for (event, expectations) in tests {
            verifyThat(event,
                       meets: expectations,
                       file: #filePath,
                       line: #line)
        }
    }

    func testFiringStartFailures() {
        // Just a convenience method to return the right expectation for each error
        func expectaton(forError error: TransparentProxyController.StartError) -> PixelFireExpectations {
            switch error {
            case .attemptToStartWithoutBackingActiveFeatures,
                    .couldNotEncodeSettingsSnapshot,
                    .couldNotRetrieveProtocolConfiguration:
                return PixelFireExpectations(
                    pixelName: Self.startFailureFullPixelName,
                    error: error)
            case .failedToLoadConfiguration(let underlyingError),
                    .failedToSaveConfiguration(let underlyingError),
                    .failedToStartProvider(let underlyingError):
                return PixelFireExpectations(
                    pixelName: Self.startFailureFullPixelName,
                    error: error,
                    underlyingError: underlyingError)
            }
        }

        let errors: [TransparentProxyController.StartError] = [
            .attemptToStartWithoutBackingActiveFeatures,
            .couldNotEncodeSettingsSnapshot,
            .couldNotRetrieveProtocolConfiguration,
            .failedToLoadConfiguration(TestError.underlyingError),
            .failedToSaveConfiguration(TestError.underlyingError),
            .failedToStartProvider(TestError.underlyingError)
        ]

        for error in errors {
            verifyThat(TransparentProxyController.Event.startFailure(error),
                       meets: expectaton(forError: error),
                       file: #filePath,
                       line: #line)
        }
    }
}
