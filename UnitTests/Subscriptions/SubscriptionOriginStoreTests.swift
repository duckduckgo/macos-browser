//
//  SubscriptionOriginStoreTests.swift
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
@testable import DuckDuckGo_Privacy_Browser

final class SubscriptionOriginStoreTests: XCTestCase {
    private static let suiteName = "testing_subscription_origin_store"
    private var userDefaults: UserDefaults!
    private var sut: SubscriptionOriginStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        userDefaults = UserDefaults(suiteName: Self.suiteName)
        sut = SubscriptionOriginStore(userDefaults: userDefaults)
    }

    override func tearDownWithError() throws {
        userDefaults.removePersistentDomain(forName: Self.suiteName)
        userDefaults = nil
        sut = nil
        try super.tearDownWithError()
    }

    func testWhenSetOriginValueThenUserDefaultsContainsValue() {
        // GIVEN
        let value = "12345"
        XCTAssertNil(userDefaults.string(forKey: SubscriptionOriginStore.Keys.privacyProSubscriptionOriginKey))

        // WHEN
        sut.origin = value

        // THEN
        XCTAssertEqual(userDefaults.string(forKey: SubscriptionOriginStore.Keys.privacyProSubscriptionOriginKey), value)
    }

    func testWhenSetOriginNilThenUserDefaultsDeletesValue() {
        // GIVEN
        let value = "12345"
        userDefaults.set(value, forKey: SubscriptionOriginStore.Keys.privacyProSubscriptionOriginKey)

        // WHEN
        sut.origin = nil

        // THEN
        XCTAssertNil(userDefaults.string(forKey: SubscriptionOriginStore.Keys.privacyProSubscriptionOriginKey))
    }

    func testWhenUserDefaultContainsOriginReturnOriginValue() {
        // GIVEN
        let value = "12345"
        userDefaults.set(value, forKey: SubscriptionOriginStore.Keys.privacyProSubscriptionOriginKey)

        // WHEN
        let result = sut.origin

        // THEN
        XCTAssertEqual(result, value)
    }

    func testWhenUserDefaultsDoesNotContainValueReturnNil() {
        // GIVEN
        userDefaults.set(nil, forKey: SubscriptionOriginStore.Keys.privacyProSubscriptionOriginKey)

        // WHEN
        let result = sut.origin

        // THEN
        XCTAssertNil(result)
    }
}
