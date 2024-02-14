//
//  TransparentProxyProviderPixelTests.swift
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

extension TransparentProxyProvider.Event: Hashable {
    public static func == (lhs: NetworkProtectionProxy.TransparentProxyProvider.Event, rhs: NetworkProtectionProxy.TransparentProxyProvider.Event) -> Bool {

        lhs.name == rhs.name && lhs.parameters == rhs.parameters
    }

    public func hash(into hasher: inout Hasher) {
        name.hash(into: &hasher)
        parameters.hash(into: &hasher)
    }
}

final class TransparentProxyProviderPixelTests: XCTestCase {

    static let startFailureFullPixelName = "m_mac_vpn_proxy_provider_start_failure"
    static let startInitiatedFullPixelName = "m_mac_vpn_proxy_provider_start_initiated"
    static let startSuccessFullPixelName = "m_mac_vpn_proxy_provider_start_success"

    enum TestError: Error {
        case testError
    }

    // MARK: - Test Firing Pixels

    func testFiringPixels() {
        let tests: [TransparentProxyProvider.Event: PixelFireExpectations] = [
            .startInitiated: PixelFireExpectations(pixelName: Self.startInitiatedFullPixelName),
            .startFailure(TestError.testError):
                PixelFireExpectations(
                    pixelName: Self.startFailureFullPixelName,
                    error: TestError.testError),
            .startSuccess: PixelFireExpectations(pixelName: Self.startSuccessFullPixelName)
        ]

        for (event, expectations) in tests {
            verifyThat(event,
                       meets: expectations,
                       file: #filePath,
                       line: #line)
        }
    }
}
