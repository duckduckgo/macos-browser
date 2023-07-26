//
//  ExtractedProfileTests.swift
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

final class ExtractedProfileTests: XCTestCase {

    func testWhenExtractedProfileDoesNotHaveAName_thenMergeAddsProfileQueryNameToIt() {
        let profileQuery = ProfileQuery(firstName: "John", lastName: "Doe", city: "Los Angeles", state: "CA", age: 45)
        let extractedProfile = ExtractedProfile()

        let sut = extractedProfile.merge(with: profileQuery)

        XCTAssertEqual(sut.name, "John Doe")
    }

    func testWhenExtractedProfileHasAName_thenMergeLeavesExtractedProfileName() {
        let profileQuery = ProfileQuery(firstName: "John", lastName: "Doe", city: "Los Angeles", state: "CA", age: 45)
        let extractedProfile = ExtractedProfile(name: "Ben Smith")

        let sut = extractedProfile.merge(with: profileQuery)

        XCTAssertEqual(sut.name, "Ben Smith")
    }

    func testWhenExtractedProfileDoesNotHaveAge_thenMergeAddsProfileQueryAgeToIt() {
        let profileQuery = ProfileQuery(firstName: "John", lastName: "Doe", city: "Los Angeles", state: "CA", age: 45)
        let extractedProfile = ExtractedProfile()

        let sut = extractedProfile.merge(with: profileQuery)

        XCTAssertEqual(sut.age, "45")
    }

    func testWhenExtractedProfileHasAge_thenMergeLeavesExtractedProfileAge() {
        let profileQuery = ProfileQuery(firstName: "John", lastName: "Doe", city: "Los Angeles", state: "CA", age: 45)
        let extractedProfile = ExtractedProfile(age: "52")

        let sut = extractedProfile.merge(with: profileQuery)

        XCTAssertEqual(sut.age, "52")
    }
}
