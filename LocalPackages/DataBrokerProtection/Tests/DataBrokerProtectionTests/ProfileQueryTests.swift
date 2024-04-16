//
//  ProfileQueryTests.swift
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

import XCTest
import Foundation
@testable import DataBrokerProtection

final class ProfileQueryTests: XCTestCase {

    func testWhenTwoProfileQueryHaveANilAndAnEmptyMiddleName_theyAreStillTheSameQuery() {
        let profileQueryOne = ProfileQuery(firstName: "John", lastName: "Doe", middleName: nil, city: "Miami", state: "FL", birthYear: 1950)
        let profileQueryTwo = ProfileQuery(firstName: "John", lastName: "Doe", middleName: "", city: "Miami", state: "FL", birthYear: 1950)

        XCTAssertTrue(profileQueryOne == profileQueryTwo)
    }

    func testWhenTwoProfileQueryHaveANilAndABlankMiddleName_theyAreStillTheSameQuery() {
        let profileQueryOne = ProfileQuery(firstName: "John", lastName: "Doe", middleName: nil, city: "Miami", state: "FL", birthYear: 1950)
        let profileQueryTwo = ProfileQuery(firstName: "John", lastName: "Doe", middleName: "        ", city: "Miami", state: "FL", birthYear: 1950)

        XCTAssertTrue(profileQueryOne == profileQueryTwo)
    }

    func testWhenTwoProfileQueryHaveTheSameMiddleNames_theyAreTheSameQuery() {
        let profileQueryOne = ProfileQuery(firstName: "John", lastName: "Doe", middleName: "M", city: "Miami", state: "FL", birthYear: 1950)
        let profileQueryTwo = ProfileQuery(firstName: "John", lastName: "Doe", middleName: "M", city: "Miami", state: "FL", birthYear: 1950)

        XCTAssertTrue(profileQueryOne == profileQueryTwo)
    }

    func testWhenTwoProfileQueryHaveDifferentMiddleNames_theyAreDifferentQueries() {
        let profileQueryOne = ProfileQuery(firstName: "John", lastName: "Doe", middleName: "M.", city: "Miami", state: "FL", birthYear: 1950)
        let profileQueryTwo = ProfileQuery(firstName: "John", lastName: "Doe", middleName: "J.", city: "Miami", state: "FL", birthYear: 1950)

        XCTAssertFalse(profileQueryOne == profileQueryTwo)
    }
}
