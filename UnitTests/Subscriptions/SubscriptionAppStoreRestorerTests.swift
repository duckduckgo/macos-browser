//
//  SubscriptionAppStoreRestorerTests.swift
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

import XCTest
@testable import Subscription
import SubscriptionTestingUtilities
@testable import DuckDuckGo_Privacy_Browser
@testable import PixelKit
import PixelKitTestingUtilities

@available(macOS 12.0, *)
final class SubscriptionAppStoreRestorerTests: XCTestCase {

//    var subscriptionManager: SubscriptionManager

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {

        let accountManager = AccountManagerMock()
        let apiService = APIServiceMock(mockAuthHeaders: [:], mockAPICallResults: .success(true))

        let subscriptionEndpointService = SubscriptionEndpointServiceMock()

        let authEndpointService = AuthEndpointServiceMock()

        let storePurchaseManager = StorePurchaseManagerMock(purchasedProductIDs: <#T##[String]#>,
                                                            purchaseQueue: <#T##[String]#>,
                                                            areProductsAvailable: <#T##Bool#>,
                                                            subscriptionOptionsResult: <#T##SubscriptionOptions?#>,
                                                            syncAppleIDAccountResultError: <#T##Error?#>,
                                                            mostRecentTransactionResult: <#T##String?#>,
                                                            hasActiveSubscriptionResult: <#T##Bool#>,
                                                            purchaseSubscriptionResult: <#T##Result<StorePurchaseManager.TransactionJWS, PurchaseManagerError>#>)

        let subscriptionManager = SubscriptionManagerMock(accountManager: accountManager,
                                                          subscriptionEndpointService: subscriptionEndpointService,
                                                          authEndpointService: authEndpointService,
                                                          storePurchaseManager: <#T##StorePurchaseManager#>,
                                                          currentEnvironment: <#T##SubscriptionEnvironment#>,
                                                          canPurchase: <#T##Bool#>)

        let subscriptionAppStoreRestorer = DefaultSubscriptionAppStoreRestorer(subscriptionManager: <#T##SubscriptionManager#>,
                                                                               subscriptionErrorReporter: <#T##SubscriptionErrorReporter#>,
                                                                               appStoreRestoreFlow: <#T##AppStoreRestoreFlow#>,
                                                                               uiHandler: <#T##SubscriptionUIHandling#>)

    }
}
