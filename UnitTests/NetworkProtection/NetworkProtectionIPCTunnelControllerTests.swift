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
import PixelKit
import PixelKitTestingUtilities
import XCTest
@testable import DuckDuckGo_Privacy_Browser

final class NetworkProtectionIPCTunnelControllerTests: XCTestCase {

    // MARK: - Tunnel Start Tests

    func testStartTunnelSuccess() async {
        let pixelKit = PixelKitMock(expecting: [
            .init(pixel: NetworkProtectionIPCTunnelController.StartAttempt.begin, frequency: .standard),
            .init(pixel: NetworkProtectionIPCTunnelController.StartAttempt.success, frequency: .dailyAndCount)
        ])
        let controller = NetworkProtectionIPCTunnelController(
            featureVisibility: MockFeatureVisibility(),
            loginItemsManager: MockLoginItemsManager(mockResult: .success),
            ipcClient: MockIPCClient(),
            pixelKit: pixelKit)

        await controller.start()

        pixelKit.verifyExpectations(file: #file, line: #line)
    }

    func testStartTunnelLoginItemFailure() async {
        let error = NSError(domain: "test", code: 1)
        let expectedError = NetworkProtectionIPCTunnelController.RequestError.internalLoginItemError(error)

        let pixelKit = PixelKitMock(expecting: [
            .init(pixel: NetworkProtectionIPCTunnelController.StartAttempt.begin, frequency: .standard),
            .init(pixel: NetworkProtectionIPCTunnelController.StartAttempt.failure(expectedError), frequency: .dailyAndCount)
        ])

        let controller = NetworkProtectionIPCTunnelController(
            featureVisibility: MockFeatureVisibility(),
            loginItemsManager: MockLoginItemsManager(mockResult: .failure(error)),
            ipcClient: MockIPCClient(),
            pixelKit: pixelKit)

        await controller.start()

        pixelKit.verifyExpectations(file: #file, line: #line)
    }

    func testStartTunnelIPCFailure() async {
        let error = NSError(domain: "test", code: 1)
        let pixelKit = PixelKitMock(expecting: [
            .init(pixel: NetworkProtectionIPCTunnelController.StartAttempt.begin, frequency: .standard),
            .init(pixel: NetworkProtectionIPCTunnelController.StartAttempt.failure(error), frequency: .dailyAndCount)
        ])
        let controller = NetworkProtectionIPCTunnelController(
            featureVisibility: MockFeatureVisibility(),
            loginItemsManager: MockLoginItemsManager(mockResult: .success),
            ipcClient: MockIPCClient(error: error),
            pixelKit: pixelKit)

        await controller.start()

        pixelKit.verifyExpectations(file: #file, line: #line)
    }

    // MARK: - Tunnel Stop Tests

    func testStopTunnelSuccess() async {
        let pixelKit = PixelKitMock(expecting: [
            .init(pixel: NetworkProtectionIPCTunnelController.StopAttempt.begin, frequency: .standard),
            .init(pixel: NetworkProtectionIPCTunnelController.StopAttempt.success, frequency: .dailyAndCount)
        ])
        let controller = NetworkProtectionIPCTunnelController(
            featureVisibility: MockFeatureVisibility(),
            loginItemsManager: MockLoginItemsManager(mockResult: .success),
            ipcClient: MockIPCClient(),
            pixelKit: pixelKit)

        await controller.stop()

        pixelKit.verifyExpectations(file: #file, line: #line)
    }

    func testStopTunnelLoginItemFailure() async {
        let error = NSError(domain: "test", code: 1)
        let expectedError = NetworkProtectionIPCTunnelController.RequestError.internalLoginItemError(error)

        let pixelKit = PixelKitMock(expecting: [
            .init(pixel: NetworkProtectionIPCTunnelController.StopAttempt.begin, frequency: .standard),
            .init(pixel: NetworkProtectionIPCTunnelController.StopAttempt.failure(expectedError), frequency: .dailyAndCount)
        ])

        let controller = NetworkProtectionIPCTunnelController(
            featureVisibility: MockFeatureVisibility(),
            loginItemsManager: MockLoginItemsManager(mockResult: .failure(error)),
            ipcClient: MockIPCClient(),
            pixelKit: pixelKit)

        await controller.stop()

        pixelKit.verifyExpectations(file: #file, line: #line)
    }

    func testStopTunnelIPCFailure() async {
        let error = NSError(domain: "test", code: 1)
        let pixelKit = PixelKitMock(expecting: [
            .init(pixel: NetworkProtectionIPCTunnelController.StopAttempt.begin, frequency: .standard),
            .init(pixel: NetworkProtectionIPCTunnelController.StopAttempt.failure(error), frequency: .dailyAndCount)
        ])
        let controller = NetworkProtectionIPCTunnelController(
            featureVisibility: MockFeatureVisibility(),
            loginItemsManager: MockLoginItemsManager(mockResult: .success),
            ipcClient: MockIPCClient(error: error),
            pixelKit: pixelKit)

        await controller.stop()

        pixelKit.verifyExpectations(file: #file, line: #line)
    }
}
