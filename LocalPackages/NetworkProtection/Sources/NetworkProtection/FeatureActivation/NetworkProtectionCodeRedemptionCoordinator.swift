//
//  NetworkProtectionCodeRedemptionCoordinator.swift
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
import Common

public protocol NetworkProtectionCodeRedeeming {

    /// Redeems an invite code with the Network Protection backend and stores the resulting auth token
    func redeem(_ code: String) async throws
}

/// Coordinates calls to the backend and oAuth token storage
public final class NetworkProtectionCodeRedemptionCoordinator: NetworkProtectionCodeRedeeming {
    private let networkClient: NetworkProtectionClient
    private let tokenStore: NetworkProtectionTokenStore
    private let versionStore: NetworkProtectionLastVersionRunStore
    private let errorEvents: EventMapping<NetworkProtectionError>

    public init(networkClient: NetworkProtectionClient = NetworkProtectionBackendClient(),
                tokenStore: NetworkProtectionTokenStore,
                versionStore: NetworkProtectionLastVersionRunStore = .init(),
                errorEvents: EventMapping<NetworkProtectionError>) {
        self.networkClient = networkClient
        self.tokenStore = tokenStore
        self.versionStore = versionStore
        self.errorEvents = errorEvents
    }

    public func redeem(_ code: String) async throws {
        let result = await networkClient.redeem(inviteCode: code)
        switch result {
        case .success(let token):
            tokenStore.store(token)
            // enable version checker on next run
            versionStore.lastVersionRun = AppVersion.shared.versionNumber

        case .failure(let error):
            errorEvents.fire(error.networkProtectionError)
            throw error
        }
    }
}
