//
//  SubscriptionErrorReporterTests.swift
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
@testable import DuckDuckGo_Privacy_Browser
@testable import PixelKit
import PixelKitTestingUtilities

final class SubscriptionErrorReporterTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    let testUserDefault = UserDefaults(suiteName: #function)!
    let reporter = SubscriptionErrorReporter()

    func handle(error: SubscriptionError, expectedPixel: PrivacyProPixel) async throws {
        let pixelExpectation = expectation(description: "Pixel fired")
        pixelExpectation.expectedFulfillmentCount = 2 // All pixels are .dailyAndCount
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
        reporter.report(subscriptionActivationError: error)
        await fulfillment(of: [pixelExpectation], timeout: 1.0)
        PixelKit.tearDown()
        pixelKit.clearFrequencyHistoryForAllPixels()
    }

    func testErrorHandling() async throws {
        try await handle(error: .purchaseFailed, expectedPixel: .privacyProPurchaseFailureStoreError)
        try await handle(error: .missingEntitlements, expectedPixel: .privacyProPurchaseFailureBackendError)
        try await handle(error: .failedToGetSubscriptionOptions, expectedPixel: .privacyProPurchaseFailureStoreError)
        // ... TBC
    }

}
