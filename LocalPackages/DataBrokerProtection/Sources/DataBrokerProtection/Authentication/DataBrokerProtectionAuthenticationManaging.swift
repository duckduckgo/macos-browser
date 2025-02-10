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

public enum AuthenticationError: Error, Equatable {
    case noInviteCode
    case cantGenerateURL
    case noAuthToken
    case issueRedeemingInviteCode(error: String)
}

public protocol DataBrokerProtectionAuthenticationManaging {
    var isUserAuthenticated: Bool { get }
    var accessToken: String? { get }
    func hasValidEntitlement() async throws -> Bool
    func getAuthHeader() -> String?
}

public final class DataBrokerProtectionAuthenticationManager: DataBrokerProtectionAuthenticationManaging {
    private let subscriptionManager: DataBrokerProtectionSubscriptionManaging

    public var isUserAuthenticated: Bool {
        subscriptionManager.isUserAuthenticated
    }

    public var accessToken: String? {
        subscriptionManager.accessToken
    }

    public init(subscriptionManager: any DataBrokerProtectionSubscriptionManaging) {
        self.subscriptionManager = subscriptionManager
    }

    public func hasValidEntitlement() async throws -> Bool {
        try await subscriptionManager.hasValidEntitlement()
    }

    public func getAuthHeader() -> String? {
        ServicesAuthHeaderBuilder().getAuthHeader(accessToken)
    }
}
