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
import Common

@available(macOS 12.0, *)
final class SubscriptionAppStoreRestorerTests: XCTestCase {

    var pixelKit: PixelKit?

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        PixelKit.tearDown()
        pixelKit?.clearFrequencyHistoryForAllPixels()
    }

    let testUserDefault = UserDefaults(suiteName: #function)!

    func testBaseSuccessfulPurchase() async throws {
        let pixelExpectation = expectation(description: "Pixel fired")
        pixelExpectation.expectedFulfillmentCount = 2 // All pixels are .dailyAndCount
        let expectedPixel = PrivacyProPixel.privacyProRestorePurchaseStoreSuccess
        let pixelKit = PixelKit(dryRun: false,
                                appVersion: "1.0.0",
                                defaultHeaders: [:],
                                defaults: testUserDefault) { pixelName, _, _, _, _, _ in
            if pixelName.hasPrefix(expectedPixel.name) {
                pixelExpectation.fulfill()
            } else {
                XCTFail("Wrong pixel fired: \(pixelName)")
            }
        }
        PixelKit.setSharedForTesting(pixelKit: pixelKit)

        let progressViewPresentedExpectation = expectation(description: "Progress view presented")
        let progressViewDismissedExpectation = expectation(description: "Progress view dismissed")

        let uiHandler = await SubscriptionUIHandlerMock { action in
            switch action {
            case .didPresentProgressViewController:
                progressViewPresentedExpectation.fulfill()
            case .didDismissProgressViewController:
                progressViewDismissedExpectation.fulfill()
            case .didUpdateProgressViewController:
                break
            case .didPresentSubscriptionAccessViewController:
                break
            case .didShowAlert:
                break
            case .didShowTab:
                break
            }
        }

        let subscriptionAppStoreRestorer = DefaultSubscriptionAppStoreRestorer(
            subscriptionManager: SubscriptionMockFactory.subscriptionManager,
            appStoreRestoreFlow: SubscriptionMockFactory.appStoreRestoreFlow,
            uiHandler: uiHandler)
        await subscriptionAppStoreRestorer.restoreAppStoreSubscription()

        await fulfillment(of: [progressViewDismissedExpectation,
                               progressViewPresentedExpectation,
                               pixelExpectation], timeout: 3.0)
    }
}
