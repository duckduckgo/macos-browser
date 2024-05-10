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
import SubscriptionTestUtils
@testable import DuckDuckGo_Privacy_Browser

final class SubscriptionRedirectManagerTests: XCTestCase {
    private var sut: PrivacyProSubscriptionRedirectManager!
    private var storeMock: SubscriptionOriginStoreMock!

    override func setUpWithError() throws {
        try super.setUpWithError()
        storeMock = .init()
        sut = PrivacyProSubscriptionRedirectManager(featureAvailabiltyProvider: true, originStore: storeMock)
    }

    override func tearDownWithError() throws {
        storeMock = nil
        sut = nil
        try super.tearDownWithError()
    }

    func testWhenURLIsPrivacyProAndHasOriginQueryParameterThenRedirectToSubscriptionBaseURLAndAppendQueryParameter() throws {
        // GIVEN
        let url = try XCTUnwrap(URL(string: "https://www.duckduckgo.com/pro?origin=test"))
        let expectedURL = URL.subscriptionBaseURL.appending(percentEncodedQueryItem: .init(name: "origin", value: "test"))

        // WHEN
        let result = sut.redirectURL(for: url)

        // THEN
        XCTAssertEqual(result, expectedURL)
    }

    func testWhenURLIsPrivacyProAndDoesNotHaveOriginQueryParameterThenRedirectToSubscriptionBaseURL() throws {
        // GIVEN
        let url = try XCTUnwrap(URL(string: "https://www.duckduckgo.com/pro"))
        let expectedURL = URL.subscriptionBaseURL

        // WHEN
        let result = sut.redirectURL(for: url)

        // THEN
        XCTAssertEqual(result, expectedURL)
    }

    func testWhenURLIsPrivacyProAndHasOriginQueryParameterThenSetOriginValueInStore() throws {
        // GIVEN
        let url = try XCTUnwrap(URL(string: "https://www.duckduckgo.com/pro?origin=test"))
        XCTAssertNil(storeMock.origin)

        // WHEN
        let result = sut.redirectURL(for: url)

        // THEN
        XCTAssertEqual(storeMock.origin, "test")
    }

    func testWhenURLIsPrivacyProAndDoesNotHaveOriginQueryParameterThenSetNilOriginValueInStore() throws {
        // GIVEN
        let url = try XCTUnwrap(URL(string: "https://www.duckduckgo.com/pro"))
        storeMock.origin = "test"

        // WHEN
        let result = sut.redirectURL(for: url)

        // THEN
        XCTAssertNil(storeMock.origin)
    }

}
