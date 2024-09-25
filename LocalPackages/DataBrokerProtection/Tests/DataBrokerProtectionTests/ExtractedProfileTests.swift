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
        let profileQuery = ProfileQuery(firstName: "John", lastName: "Doe", city: "Los Angeles", state: "CA", birthYear: 1980)
        let extractedProfile = ExtractedProfile()

        let sut = extractedProfile.merge(with: profileQuery)

        XCTAssertEqual(sut.name, "John Doe")
    }

    func testWhenExtractedProfileHasAName_thenMergeLeavesExtractedProfileName() {
        let profileQuery = ProfileQuery(firstName: "John", lastName: "Doe", city: "Los Angeles", state: "CA", birthYear: 1980)
        let extractedProfile = ExtractedProfile(name: "Ben Smith")

        let sut = extractedProfile.merge(with: profileQuery)

        XCTAssertEqual(sut.name, "Ben Smith")
    }

    func testWhenExtractedProfileDoesNotHaveAge_thenMergeAddsProfileQueryAgeToIt() {
        let birthYear = 1980
        let profileQuery = ProfileQuery(firstName: "John", lastName: "Doe", city: "Los Angeles", state: "CA", birthYear: birthYear)
        let extractedProfile = ExtractedProfile()

        let currentYear = Calendar.current.component(.year, from: Date())
        let age = currentYear - birthYear

        let sut = extractedProfile.merge(with: profileQuery)

        XCTAssertEqual(sut.age, "\(age)")
    }

    func testWhenExtractedProfileHasAge_thenMergeLeavesExtractedProfileAge() {
        let profileQuery = ProfileQuery(firstName: "John", lastName: "Doe", city: "Los Angeles", state: "CA", birthYear: 1980)
        let extractedProfile = ExtractedProfile(age: "52")

        let sut = extractedProfile.merge(with: profileQuery)

        XCTAssertEqual(sut.age, "52")
    }

    // MARK: - Test matching logic

    func testDoesMatchExtractedProfile_whenThereAnExactMatch_thenDoesMatchExtractedProfileIsTrue() {

        // Given
        let extractedProfile = ExtractedProfile.mockWithName("Steve Jones",
                                                             alternativeNames: ["Steven Jones",
                                                                                "Steven M Jones"],
                                                             age: "20",
                                                             addresses: [AddressCityState(city: "New York", state: "NY"),
                                                                         AddressCityState(city: "Miami", state: "FL")],
                                                             relatives: ["Steven Jones Jr",
                                                                         "Steven Jones Sr",
                                                                         "Steven Jones Staff",
                                                                         "Steven Jones Principle"])
        let matchingExtractedProfile = ExtractedProfile.mockWithName("Steve Jones",
                                                                     alternativeNames: ["Steven Jones",
                                                                                        "Steven M Jones"],
                                                                     age: "20",
                                                                     addresses: [AddressCityState(city: "New York", state: "NY"),
                                                                                 AddressCityState(city: "Miami", state: "FL")],
                                                                     relatives: ["Steven Jones Jr",
                                                                                 "Steven Jones Sr",
                                                                                 "Steven Jones Staff",
                                                                                 "Steven Jones Principle"])

        // Then
        XCTAssertTrue(extractedProfile.doesMatchExtractedProfile(matchingExtractedProfile))
    }

    func testDoesMatchExtractedProfile_whenThereIsANonMatch_thenDoesMatchExtractedProfileIsFalse() {

        // Given
        let extractedProfile = ExtractedProfile.mockWithName("Steve Jones",
                                                             alternativeNames: ["Steven Jones",
                                                                                "Steven M Jones"],
                                                             age: "20",
                                                             addresses: [AddressCityState(city: "New York", state: "NY"),
                                                                         AddressCityState(city: "Miami", state: "FL")],
                                                             relatives: ["Steven Jones Jr",
                                                                         "Steven Jones Sr",
                                                                         "Steven Jones Staff",
                                                                         "Steven Jones Principle"])
        let nonmatchingExtractedProfile = ExtractedProfile.mockWithName("James Smith",
                                                                        alternativeNames: ["James Jameson and The Legion of Doom"],
                                                                        age: "57",
                                                                        addresses: [AddressCityState(city: "Blackpool", state: "NY"),
                                                                                    AddressCityState(city: "Underneath a Volcano", state: "FL")],
                                                                        relatives: ["Beelzebub",
                                                                                    "Barney the Dinosaur"])

        // Then
        XCTAssertFalse(extractedProfile.doesMatchExtractedProfile(nonmatchingExtractedProfile))
    }

    func testDoesMatchExtractedProfile_whenThereAPartialMatch_thenDoesMatchExtractedProfileIsFalse() {

        // Given
        let extractedProfile = ExtractedProfile.mockWithName("Steve Jones",
                                                             alternativeNames: ["Steven Jones",
                                                                                "Steven M Jones"],
                                                             age: "20",
                                                             addresses: [AddressCityState(city: "New York", state: "NY"),
                                                                         AddressCityState(city: "Miami", state: "FL")],
                                                             relatives: ["Steven Jones Jr",
                                                                         "Steven Jones Sr",
                                                                         "Steven Jones Staff",
                                                                         "Steven Jones Principle"])
        let nonmatchingExtractedProfile = ExtractedProfile.mockWithName("Steve Jones",
                                                                        alternativeNames: ["Steven Jones",
                                                                                           "Steven M Jones"],
                                                                        age: "30",
                                                                        addresses: [AddressCityState(city: "New York", state: "NY"),
                                                                                    AddressCityState(city: "Miami", state: "FL")],
                                                                        relatives: ["Steven Jones Jr",
                                                                                    "Steven Jones Sr",
                                                                                    "Steven Jones Staff",
                                                                                    "Steven Jones Principle"])

        // Then
        XCTAssertFalse(extractedProfile.doesMatchExtractedProfile(nonmatchingExtractedProfile))
    }

    func testDoesMatchExtractedProfile_whenThereASubsetMatch_thenDoesMatchExtractedProfileIsTrue() {

        // Given
        let extractedProfile = ExtractedProfile.mockWithName("Steve Jones",
                                                             alternativeNames: ["Steven Jones",
                                                                                "Steven M Jones"],
                                                             age: "20",
                                                             addresses: [AddressCityState(city: "New York", state: "NY"),
                                                                         AddressCityState(city: "Miami", state: "FL")],
                                                             relatives: ["Steven Jones Jr",
                                                                         "Steven Jones Sr",
                                                                         "Steven Jones Staff",
                                                                         "Steven Jones Principle"])
        let matchingExtractedProfile = ExtractedProfile.mockWithName("Steve Jones",
                                                                     alternativeNames: ["Steven Jones"],
                                                                     age: "20",
                                                                     addresses: [AddressCityState(city: "Miami", state: "FL")],
                                                                     relatives: [])

        // Then
        XCTAssertTrue(extractedProfile.doesMatchExtractedProfile(matchingExtractedProfile))
    }

    func testDoesMatchExtractedProfile_whenThereIsASupersetMatch_thenDoesMatchExtractedProfileIsTrue() {

        // Given
        let extractedProfile = ExtractedProfile.mockWithName("Steve Jones",
                                                             alternativeNames: [],
                                                             age: "20",
                                                             addresses: [AddressCityState(city: "Miami", state: "FL")],
                                                             relatives: ["Steven Jones Staff",
                                                                         "Steven Jones Principle"])
        let matchingExtractedProfile = ExtractedProfile.mockWithName("Steve Jones",
                                                                     alternativeNames: ["Steven Jones",
                                                                                        "Steven M Jones"],
                                                                     age: "20",
                                                                     addresses: [AddressCityState(city: "New York", state: "NY"),
                                                                                 AddressCityState(city: "Miami", state: "FL")],
                                                                     relatives: ["Steven Jones Jr",
                                                                                 "Steven Jones Sr",
                                                                                 "Steven Jones Staff",
                                                                                 "Steven Jones Principle"])

        // Then
        XCTAssertTrue(extractedProfile.doesMatchExtractedProfile(matchingExtractedProfile))
    }

    // When some fields are subsets, and some are supersets
    func testDoesMatchExtractedProfile_whenThereAMixedSubsetSupersetMatch_thenDoesMatchExtractedProfileIsTrue() {

        // Given
        let extractedProfile = ExtractedProfile.mockWithName("Steve Jones",
                                                             alternativeNames: [],
                                                             age: "20",
                                                             addresses: [],
                                                             relatives: ["Steven Jones Jr",
                                                                         "Steven Jones Sr",
                                                                         "Steven Jones Staff",
                                                                         "Steven Jones Principle"])
        let matchingExtractedProfile = ExtractedProfile.mockWithName("Steve Jones",
                                                                     alternativeNames: ["Steven Jones",
                                                                                        "Steven M Jones"],
                                                                     age: "20",
                                                                     addresses: [AddressCityState(city: "New York", state: "NY"),
                                                                                 AddressCityState(city: "Miami", state: "FL")],
                                                                     relatives: ["Steven Jones Jr",
                                                                                 "Steven Jones Principle"])

        // Then
        XCTAssertTrue(extractedProfile.doesMatchExtractedProfile(matchingExtractedProfile))
    }
}
