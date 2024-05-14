//
//  DataBrokerProtectionAuthenticationManaging.swift
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

public protocol DataBrokerProtectionAuthenticationManaging {
    var isUserAuthenticated: Bool { get }
    var accessToken: String? { get }
    func hasValidEntitlement() async -> Result<Bool, Error>
    func shouldAskForInviteCode() -> Bool
    func redeem(inviteCode: String) async throws
    func getAuthHeader() -> String?
}

public final class DataBrokerProtectionAuthenticationManager: DataBrokerProtectionAuthenticationManaging {
    private let redeemUseCase: DataBrokerProtectionRedeemUseCase
    private let subscriptionManager: DataBrokerProtectionSubscriptionManaging

    public var isUserAuthenticated: Bool {
        subscriptionManager.isUserAuthenticated
    }

    public var accessToken: String? {
        subscriptionManager.accessToken
    }

    public init(redeemUseCase: any DataBrokerProtectionRedeemUseCase,
                subscriptionManager: any DataBrokerProtectionSubscriptionManaging) {
        self.redeemUseCase = redeemUseCase
        self.subscriptionManager = subscriptionManager
    }

    public func hasValidEntitlement() async -> Result<Bool, any Error> {
        await subscriptionManager.hasValidEntitlement()
    }

    public func getAuthHeader() -> String? {
        ServicesAuthHeaderBuilder().getAuthHeader(accessToken)
    }

    // MARK: - Redeem code flow

    // We might want the ability to ask for invite code later on, keeping this here to make things easier
    // https://app.asana.com/0/1204167627774280/1207270521849479/f

    public func shouldAskForInviteCode() -> Bool {
        // redeemUseCase.shouldAskForInviteCode()
        return false
    }

    public func redeem(inviteCode: String) async throws {
        // await redeemUseCase.redeem(inviteCode: inviteCode)
    }
}
