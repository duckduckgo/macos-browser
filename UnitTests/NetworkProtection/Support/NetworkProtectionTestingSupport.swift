//
//  NetworkProtectionTestingSupport.swift
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
import Common
import Foundation
import LoginItems
import NetworkProtection
import NetworkProtectionUI
@testable import DuckDuckGo_Privacy_Browser

struct MockFeatureVisibility: NetworkProtectionFeatureVisibility {
    let isEligibleForThankYouMessage: Bool
    let isInstalled: Bool
    let canStartVPNValue: Bool
    let isVPNVisibleValue: Bool
    let isNetworkProtectionBetaVisibleValue: Bool
    let shouldUninstallAutomaticallyValue: Bool
    let disableIfUserHasNoAccessValue: Bool

    func canStartVPN() async throws -> Bool {
        canStartVPNValue
    }

    func isVPNVisible() -> Bool {
        isVPNVisibleValue
    }

    func isNetworkProtectionBetaVisible() -> Bool {
        isNetworkProtectionBetaVisibleValue
    }

    func shouldUninstallAutomatically() -> Bool {
        shouldUninstallAutomaticallyValue
    }

    func disableForAllUsers() async {
        // Intentional no-op
    }

    func disableForWaitlistUsers() {
        // Intentional no-op
    }

    func disableIfUserHasNoAccess() async -> Bool {
        disableIfUserHasNoAccessValue
    }

    let onboardStatusPublisher: AnyPublisher<NetworkProtectionUI.OnboardingStatus, Never>

    init(isEligibleForThankYouMessage: Bool = false,
         isInstalled: Bool = false,
         canStartVPNValue: Bool = true,
         isVPNVisibleValue: Bool = true,
         isNetworkProtectionBetaVisibleValue: Bool = false,
         shouldUninstallAutomaticallyValue: Bool = false,
         disableIfUserHasNoAccessValue: Bool = false,
         onboardStatusPublisher: AnyPublisher<NetworkProtectionUI.OnboardingStatus, Never> = Just(.default).eraseToAnyPublisher()) {

        self.isEligibleForThankYouMessage = isEligibleForThankYouMessage
        self.isInstalled = isInstalled
        self.canStartVPNValue = canStartVPNValue
        self.isVPNVisibleValue = isVPNVisibleValue
        self.isNetworkProtectionBetaVisibleValue = isNetworkProtectionBetaVisibleValue
        self.shouldUninstallAutomaticallyValue = shouldUninstallAutomaticallyValue
        self.disableIfUserHasNoAccessValue = disableIfUserHasNoAccessValue
        self.onboardStatusPublisher = onboardStatusPublisher
    }
}

struct MockConnectionStatusObserver: ConnectionStatusObserver {
    var publisher: AnyPublisher<NetworkProtection.ConnectionStatus, Never> = Just(.disconnected).eraseToAnyPublisher()

    var recentValue: NetworkProtection.ConnectionStatus = .disconnected
}

struct MockServerInfoObserver: ConnectionServerInfoObserver {
    var publisher: AnyPublisher<NetworkProtection.NetworkProtectionStatusServerInfo, Never> = Just(.unknown).eraseToAnyPublisher()

    var recentValue: NetworkProtection.NetworkProtectionStatusServerInfo = .unknown
}

struct MockConnectionErrorObserver: ConnectionErrorObserver {
    var publisher: AnyPublisher<String?, Never> = Just(nil).eraseToAnyPublisher()

    var recentValue: String?
}

struct MockDataVolumeObserver: DataVolumeObserver {
    var publisher: AnyPublisher<DataVolume, Never> = Just(.init()).eraseToAnyPublisher()

    var recentValue: DataVolume = .init()
}

struct MockIPCClient: NetworkProtectionIPCClient {
    private let error: Error?

    var ipcStatusObserver: NetworkProtection.ConnectionStatusObserver = MockConnectionStatusObserver()
    var ipcServerInfoObserver: NetworkProtection.ConnectionServerInfoObserver = MockServerInfoObserver()
    var ipcConnectionErrorObserver: NetworkProtection.ConnectionErrorObserver = MockConnectionErrorObserver()
    var ipcDataVolumeObserver: any NetworkProtection.DataVolumeObserver = MockDataVolumeObserver()

    init(error: Error? = nil) {
        self.error = error
    }

    func start(completion: @escaping (Error?) -> Void) {
        completion(error)
    }

    func stop(completion: @escaping (Error?) -> Void) {
        completion(error)
    }
}

struct MockLoginItemsManager: LoginItemsManaging {

    enum MockResult {
        case success
        case failure(_ error: Error)
    }

    private let mockResult: MockResult

    init(mockResult: MockResult) {
        self.mockResult = mockResult
    }

    func throwingEnableLoginItems(_ items: Set<LoginItems.LoginItem>, log: Common.OSLog) throws {
        switch mockResult {
        case .success:
            return
        case .failure(let error):
            throw error
        }
    }
}
