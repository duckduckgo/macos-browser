//
//  SubscriptionMockFactory.swift
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
@testable import Subscription
import SubscriptionTestingUtilities
@testable import DuckDuckGo_Privacy_Browser

/// Provides all mock needed for testing subscription initialised with positive outcomes and basic configurations. All mocks can be partially reconfigured with failures or incorrect data
struct SubscriptionMockFactory {

    static let accountManager = AccountManagerMock()
    static let apiService = APIServiceMock(mockAuthHeaders: [:], mockAPICallResults: .success(true))
    static let subscription = Subscription(productId: "1",
                                           name: "product 1",
                                           billingPeriod: .monthly,
                                           startedAt: Date(),
                                           expiresOrRenewsAt: Date().addingTimeInterval(TimeInterval.days(+30)),
                                           platform: .apple,
                                           status: .autoRenewable)
    static let productsItems: [GetProductsItem] = [GetProductsItem(productId: subscription.productId,
                                                                   productLabel: subscription.name,
                                                                   billingPeriod: subscription.billingPeriod.rawValue,
                                                                   price: "1",
                                                                   currency: "euro")]
    static let customerPortalURL = GetCustomerPortalURLResponse(customerPortalUrl: "https://duckduckgo.com")
    static let entitlements = [Entitlement(name: "dbp", product: .dataBrokerProtection),
                               Entitlement(name: "itr", product: .identityTheftRestoration),
                               Entitlement(name: "np", product: .networkProtection)]
    static let email = "test@test.com"
    static let confirmPurchase = ConfirmPurchaseResponse(email: email,
                                                         entitlements: entitlements,
                                                         subscription: subscription)
    static let subscriptionEndpointService = SubscriptionEndpointServiceMock(getSubscriptionResult: .success(subscription),
                                                                             getProductsResult: .success(productsItems),
                                                                             getCustomerPortalURLResult: .success(customerPortalURL),
                                                                             confirmPurchaseResult: .success(confirmPurchase))
    static let authToken = "someToken"

    static let authEndpointService = AuthEndpointServiceMock(accessTokenResult: .success(AccessTokenResponse(accessToken: "some")),
                                                             validateTokenResult: .success(ValidateTokenResponse(account: ValidateTokenResponse.Account(email: "test@test.com", entitlements: entitlements, externalID: "?"))),
                                                             createAccountResult: .success(CreateAccountResponse(authToken: authToken,
                                                                                                                 externalID: "?",
                                                                                                                 status: "?")),
                                                             storeLoginResult: .success(StoreLoginResponse(authToken: authToken,
                                                                                                           email: email,
                                                                                                           externalID: "?",
                                                                                                           id: 1,
                                                                                                           status: "?")))

    static let storePurchaseManager = StorePurchaseManagerMock(purchasedProductIDs: ["1"],
                                                               purchaseQueue: ["?"],
                                                               areProductsAvailable: true,
                                                               subscriptionOptionsResult: SubscriptionOptions.empty,
                                                               syncAppleIDAccountResultError: nil,
                                                               mostRecentTransactionResult: nil,
                                                               hasActiveSubscriptionResult: false,
                                                               purchaseSubscriptionResult: .success("JWS?"))

    static let currentEnvironment = SubscriptionEnvironment(serviceEnvironment: .staging,
                                                            purchasePlatform: .appStore)

    static let subscriptionManager = SubscriptionManagerMock(accountManager: accountManager,
                                                             subscriptionEndpointService: subscriptionEndpointService,
                                                             authEndpointService: authEndpointService,
                                                             storePurchaseManager: storePurchaseManager,
                                                             currentEnvironment: currentEnvironment,
                                                             canPurchase: true)

    static let appStoreRestoreFlow = AppStoreRestoreFlowMock(restoreAccountFromPastPurchaseResult: .success(Void()))

}
