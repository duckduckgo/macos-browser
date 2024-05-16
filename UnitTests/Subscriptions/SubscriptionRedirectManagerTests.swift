//
//  SubscriptionRedirectManagerTests.swift
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
import Subscription
import SubscriptionTestingUtilities
@testable import DuckDuckGo_Privacy_Browser

final class SubscriptionRedirectManagerTests: XCTestCase {
    private var sut: PrivacyProSubscriptionRedirectManager!

    override func setUpWithError() throws {
        try super.setUpWithError()
        sut = PrivacyProSubscriptionRedirectManager(featureAvailabiltyProvider: true,
                                                    subscriptionEnvironment: SubscriptionEnvironment(serviceEnvironment: .production,
                                                                                                     purchasePlatform: .appStore),
                                                    canPurchase: { true })
    }

    override func tearDownWithError() throws {
        sut = nil
        try super.tearDownWithError()
    }

    func testWhenURLIsPrivacyProAndHasOriginQueryParameterThenRedirectToSubscriptionBaseURLAndAppendQueryParameter() throws {
        // GIVEN
        let url = try XCTUnwrap(URL(string: "https://www.duckduckgo.com/pro?origin=test"))
        let baseURL = SubscriptionURL.baseURL.subscriptionURL(environment: .production)
        let expectedURL = baseURL.appending(percentEncodedQueryItem: .init(name: "origin", value: "test"))

        // WHEN
        let result = sut.redirectURL(for: url)

        // THEN
        XCTAssertEqual(result, expectedURL)
    }

    func testWhenURLIsPrivacyProAndDoesNotHaveOriginQueryParameterThenRedirectToSubscriptionBaseURL() throws {
        // GIVEN
        let url = try XCTUnwrap(URL(string: "https://www.duckduckgo.com/pro"))
        let expectedURL = SubscriptionURL.baseURL.subscriptionURL(environment: .production)

        // WHEN
        let result = sut.redirectURL(for: url)

        // THEN
        XCTAssertEqual(result, expectedURL)
    }

}
