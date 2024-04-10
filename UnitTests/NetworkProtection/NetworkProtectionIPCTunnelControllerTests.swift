//
//  NetworkProtectionIPCTunnelControllerTests.swift
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

import Combine
import Foundation
import NetworkProtection
import XCTest
@testable import DuckDuckGo_Privacy_Browser

final class NetworkProtectionIPCTunnelControllerTests: XCTestCase {

    final class AttemptHandler: VPNStartAttemptHandling, VPNStopAttemptHandling {

        enum ExpectedResult {
            case success
            case failure(_ error: Error)
        }

        private var beginCallCount = 0
        private var successCallCount = 0
        private var failureCallCount = 0
        private var error: Error?
        private let expectedResult: ExpectedResult

        init(expectedResult: ExpectedResult) {
            self.expectedResult = expectedResult
        }

        func begin() {
            beginCallCount += 1
        }

        func success() {
            successCallCount += 1
        }

        func failure(_ error: Error) {
            failureCallCount += 1
            self.error = error
        }

        var expectationsMet: Bool {
            switch expectedResult {
            case .success:
                return beginCallCount == 1 && successCallCount == 1 && failureCallCount == 0
            case .failure(let error):
                guard let expectedNSError = self.error as? NSError else {
                    return false
                }

                let nsError = error as NSError

                return beginCallCount == 1 && successCallCount == 0 && failureCallCount == 1 && nsError == expectedNSError
            }
        }
    }

    // MARK: - Tunnel Start Tests

    func testStartTunnelSuccess() async {
        let controller = NetworkProtectionIPCTunnelController(
            featureVisibility: MockFeatureVisibility(),
            loginItemsManager: MockLoginItemsManager(mockResult: .success),
            ipcClient: MockIPCClient())
        let attemptHandler = AttemptHandler(expectedResult: .success)

        await controller.start(attemptHandler: attemptHandler)

        XCTAssertTrue(attemptHandler.expectationsMet)
    }

    func testStartTunnelLoginItemFailure() async {
        let error = NSError(domain: "test", code: 1)
        let controller = NetworkProtectionIPCTunnelController(
            featureVisibility: MockFeatureVisibility(),
            loginItemsManager: MockLoginItemsManager(mockResult: .failure(error)),
            ipcClient: MockIPCClient())
        let attemptHandler = AttemptHandler(expectedResult: .failure(error))

        await controller.start(attemptHandler: attemptHandler)

        XCTAssertTrue(attemptHandler.expectationsMet)
    }

    // MARK: - Tunnel Stop Tests

    func testStopTunnelSuccess() async {
        let controller = NetworkProtectionIPCTunnelController(
            featureVisibility: MockFeatureVisibility(),
            loginItemsManager: MockLoginItemsManager(mockResult: .success),
            ipcClient: MockIPCClient())
        let attemptHandler = AttemptHandler(expectedResult: .success)

        await controller.stop(attemptHandler: attemptHandler)

        XCTAssertTrue(attemptHandler.expectationsMet)
    }

    func testStopTunnelLoginItemFailure() async {
        let error = NSError(domain: "test", code: 1)
        let controller = NetworkProtectionIPCTunnelController(
            featureVisibility: MockFeatureVisibility(),
            loginItemsManager: MockLoginItemsManager(mockResult: .failure(error)),
            ipcClient: MockIPCClient())
        let attemptHandler = AttemptHandler(expectedResult: .failure(error))

        await controller.stop(attemptHandler: attemptHandler)

        XCTAssertTrue(attemptHandler.expectationsMet)
    }
}
