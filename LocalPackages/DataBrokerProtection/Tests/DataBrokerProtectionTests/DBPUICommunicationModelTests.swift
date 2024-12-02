//
//  DBPUICommunicationModelTests.swift
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
import Foundation
@testable import DataBrokerProtection

final class DBPUICommunicationModelTests: XCTestCase {

    func testProfileMatchInit_whenCreatedDateIsNotDefault_thenResultingProfileMatchDatesAreBothBasedOnOptOutJobDataDates() {

        // Given
        let extractedProfile = ExtractedProfile.mockWithRemovedDate

        let foundEventDate = Calendar.current.date(byAdding: .day, value: -20, to: Date.now)!
        let submittedEventDate = Calendar.current.date(byAdding: .day, value: -18, to: Date.now)!
        let historyEvents = [
            HistoryEvent(extractedProfileId: 0, brokerId: 0, profileQueryId: 0, type: .matchesFound(count: 1), date: foundEventDate),
            HistoryEvent(extractedProfileId: 0, brokerId: 0, profileQueryId: 0, type: .optOutRequested, date: submittedEventDate)
        ]

        let createdDate = Calendar.current.date(byAdding: .day, value: -14, to: Date.now)!
        let submittedDate = Calendar.current.date(byAdding: .day, value: -7, to: Date.now)!
        let optOut = OptOutJobData.mock(with: extractedProfile,
                                        historyEvents: historyEvents,
                                        createdDate: createdDate,
                                        submittedSuccessfullyDate: submittedDate)

        // When
        let profileMatch = DBPUIDataBrokerProfileMatch(optOutJobData: optOut,
                                                       dataBrokerName: "doesn't matter for the test",
                                                       dataBrokerURL: "see above",
                                                       dataBrokerParentURL: "whatever",
                                                       parentBrokerOptOutJobData: nil,
                                                       optOutUrl: "broker.com")

        // Then
        XCTAssertEqual(profileMatch.foundDate, createdDate.timeIntervalSince1970)
        XCTAssertEqual(profileMatch.optOutSubmittedDate, submittedDate.timeIntervalSince1970)
    }

    func testProfileMatchInit_whenCreatedDateIsDefault_thenResultingProfileMatchDatesAreBothBasedOnEventDates() {

        // Given
        let extractedProfile = ExtractedProfile.mockWithRemovedDate

        let foundEventDate = Calendar.current.date(byAdding: .day, value: -20, to: Date.now)!
        let submittedEventDate = Calendar.current.date(byAdding: .day, value: -18, to: Date.now)!
        let historyEvents = [
            HistoryEvent(extractedProfileId: 0, brokerId: 0, profileQueryId: 0, type: .matchesFound(count: 1), date: foundEventDate),
            HistoryEvent(extractedProfileId: 0, brokerId: 0, profileQueryId: 0, type: .optOutRequested, date: submittedEventDate)
        ]

        let createdDate = Date(timeIntervalSince1970: 0)
        let submittedDate = Calendar.current.date(byAdding: .day, value: -7, to: Date.now)!
        let optOut = OptOutJobData.mock(with: extractedProfile,
                                        historyEvents: historyEvents,
                                        createdDate: createdDate,
                                        submittedSuccessfullyDate: submittedDate)

        // When
        let profileMatch = DBPUIDataBrokerProfileMatch(optOutJobData: optOut,
                                                       dataBrokerName: "doesn't matter for the test",
                                                       dataBrokerURL: "see above",
                                                       dataBrokerParentURL: "whatever",
                                                       parentBrokerOptOutJobData: nil,
                                                       optOutUrl: "broker.com")

        // Then
        XCTAssertEqual(profileMatch.foundDate, foundEventDate.timeIntervalSince1970)
        XCTAssertEqual(profileMatch.optOutSubmittedDate, submittedEventDate.timeIntervalSince1970)
    }

    func testProfileMatchInit_whenCreatedDateIsDefaultAndThereAreMultipleEventsOfTheSameType_thenResultingProfileMatchDatesAreBothBasedOnFirstEventDates() {

        // Given
        let extractedProfile = ExtractedProfile.mockWithRemovedDate

        let foundEventDate1 = Calendar.current.date(byAdding: .day, value: -20, to: Date.now)!
        let foundEventDate2 = Calendar.current.date(byAdding: .day, value: -21, to: Date.now)!
        let foundEventDate3 = Calendar.current.date(byAdding: .day, value: -19, to: Date.now)!
        let submittedEventDate1 = Calendar.current.date(byAdding: .day, value: -18, to: Date.now)!
        let submittedEventDate2 = Calendar.current.date(byAdding: .day, value: -19, to: Date.now)!
        let submittedEventDate3 = Calendar.current.date(byAdding: .day, value: -17, to: Date.now)!
        let historyEvents = [
            HistoryEvent(extractedProfileId: 0, brokerId: 0, profileQueryId: 0, type: .matchesFound(count: 1), date: foundEventDate1),
            HistoryEvent(extractedProfileId: 0, brokerId: 0, profileQueryId: 0, type: .matchesFound(count: 1), date: foundEventDate2),
            HistoryEvent(extractedProfileId: 0, brokerId: 0, profileQueryId: 0, type: .matchesFound(count: 1), date: foundEventDate3),
            HistoryEvent(extractedProfileId: 0, brokerId: 0, profileQueryId: 0, type: .optOutRequested, date: submittedEventDate1),
            HistoryEvent(extractedProfileId: 0, brokerId: 0, profileQueryId: 0, type: .optOutRequested, date: submittedEventDate2),
            HistoryEvent(extractedProfileId: 0, brokerId: 0, profileQueryId: 0, type: .optOutRequested, date: submittedEventDate3)
        ]

        let createdDate = Date(timeIntervalSince1970: 0)
        let submittedDate = Calendar.current.date(byAdding: .day, value: -7, to: Date.now)!
        let optOut = OptOutJobData.mock(with: extractedProfile,
                                        historyEvents: historyEvents,
                                        createdDate: createdDate,
                                        submittedSuccessfullyDate: submittedDate)

        // When
        let profileMatch = DBPUIDataBrokerProfileMatch(optOutJobData: optOut,
                                                       dataBrokerName: "doesn't matter for the test",
                                                       dataBrokerURL: "see above",
                                                       dataBrokerParentURL: "whatever",
                                                       parentBrokerOptOutJobData: nil,
                                                       optOutUrl: "broker.com")

        // Then
        XCTAssertEqual(profileMatch.foundDate, foundEventDate2.timeIntervalSince1970)
        XCTAssertEqual(profileMatch.optOutSubmittedDate, submittedEventDate2.timeIntervalSince1970)
    }

    /*
     test cases
     one exact matching parent
     one exact matching parent mixed in the array (probs can combnie with above
     no match
     partial match
     */

    func testProfileMatchInit_whenThereIsExactParentMatch_thenHasMatchingRecordOnParentBrokerIsTrue() {

        // Given
        let extractedProfile = ExtractedProfile.mockWithName("Steve Jones", age: "20", addresses: [AddressCityState(city: "New York", state: "NY")])
        let parentProfile = ExtractedProfile.mockWithName("Steve Jones", age: "20", addresses: [AddressCityState(city: "New York", state: "NY")])

        let optOut = OptOutJobData.mock(with: extractedProfile,
                                        historyEvents: [])
        let parentOptOut = OptOutJobData.mock(with: parentProfile,
                                              historyEvents: [])

        // When
        let profileMatch = DBPUIDataBrokerProfileMatch(optOutJobData: optOut,
                                                       dataBrokerName: "doesn't matter for the test",
                                                       dataBrokerURL: "see above",
                                                       dataBrokerParentURL: "whatever",
                                                       parentBrokerOptOutJobData: [parentOptOut],
                                                       optOutUrl: "broker.com")

        // Then
        XCTAssertTrue(profileMatch.hasMatchingRecordOnParentBroker)
    }

    func testProfileMatchInit_whenThereAreMultipleNonMatchingProfilesAndAnExactParentMatch_thenHasMatchingRecordOnParentBrokerIsTrue() {

        // Given
        let extractedProfile = ExtractedProfile.mockWithName("Steve Jones", age: "20", addresses: [AddressCityState(city: "New York", state: "NY")])
        let parentProfileMatching = ExtractedProfile.mockWithName("Steve Jones", age: "20", addresses: [AddressCityState(city: "New York", state: "NY")])
        let parentProfileNonmatching1 = ExtractedProfile.mockWithName("Steve Jones", age: "30", addresses: [AddressCityState(city: "New York", state: "NY")])
        let parentProfileNonmatching2 = ExtractedProfile.mockWithName("Jamie Jones", age: "20", addresses: [AddressCityState(city: "New York", state: "NY")])

        let optOut = OptOutJobData.mock(with: extractedProfile,
                                        historyEvents: [])
        let parentOptOutMatching = OptOutJobData.mock(with: parentProfileMatching,
                                                      historyEvents: [])
        let parentOptOutNonmatching1 = OptOutJobData.mock(with: parentProfileNonmatching1,
                                                      historyEvents: [])
        let parentOptOutNonmatching2 = OptOutJobData.mock(with: parentProfileNonmatching2,
                                                      historyEvents: [])

        // When
        let profileMatch = DBPUIDataBrokerProfileMatch(optOutJobData: optOut,
                                                       dataBrokerName: "doesn't matter for the test",
                                                       dataBrokerURL: "see above",
                                                       dataBrokerParentURL: "whatever",
                                                       parentBrokerOptOutJobData: [parentOptOutNonmatching1,
                                                                                   parentOptOutMatching,
                                                                                   parentOptOutNonmatching2],
                                                       optOutUrl: "broker.com")

        // Then
        XCTAssertTrue(profileMatch.hasMatchingRecordOnParentBroker)
    }

    func testProfileMatchInit_whenThereIsNoParentMatch_thenHasMatchingRecordOnParentBrokerIsFalse() {

        // Given
        let extractedProfile = ExtractedProfile.mockWithName("Steve Jones", age: "20", addresses: [AddressCityState(city: "New York", state: "NY")])
        let parentProfileNonmatching1 = ExtractedProfile.mockWithName("Steve Jones", age: "30", addresses: [AddressCityState(city: "New York", state: "NY")])
        let parentProfileNonmatching2 = ExtractedProfile.mockWithName("Jamie Jones", age: "20", addresses: [AddressCityState(city: "New York", state: "NY")])

        let optOut = OptOutJobData.mock(with: extractedProfile,
                                        historyEvents: [])
        let parentOptOutNonmatching1 = OptOutJobData.mock(with: parentProfileNonmatching1,
                                                      historyEvents: [])
        let parentOptOutNonmatching2 = OptOutJobData.mock(with: parentProfileNonmatching2,
                                                      historyEvents: [])

        // When
        let profileMatch = DBPUIDataBrokerProfileMatch(optOutJobData: optOut,
                                                       dataBrokerName: "doesn't matter for the test",
                                                       dataBrokerURL: "see above",
                                                       dataBrokerParentURL: "whatever",
                                                       parentBrokerOptOutJobData: [parentOptOutNonmatching1,
                                                                                   parentOptOutNonmatching2],
                                                       optOutUrl: "broker.com")

        // Then
        XCTAssertFalse(profileMatch.hasMatchingRecordOnParentBroker)
    }

    func testProfileMatchInit_whenThereIsANonExactParentMatch_thenHasMatchingRecordOnParentBrokerIsTrue() {

        // Given
        let extractedProfile = ExtractedProfile.mockWithName("Steve Jones", age: "20", addresses: [AddressCityState(city: "New York", state: "NY")])
        let parentProfile = ExtractedProfile.mockWithName("Steve Jones", age: "20", addresses: [AddressCityState(city: "New York", state: "NY"), AddressCityState(city: "Atlanta", state: "GA")])

        let optOut = OptOutJobData.mock(with: extractedProfile,
                                        historyEvents: [])
        let parentOptOut = OptOutJobData.mock(with: parentProfile,
                                              historyEvents: [])

        // When
        let profileMatch = DBPUIDataBrokerProfileMatch(optOutJobData: optOut,
                                                       dataBrokerName: "doesn't matter for the test",
                                                       dataBrokerURL: "see above",
                                                       dataBrokerParentURL: "whatever",
                                                       parentBrokerOptOutJobData: [parentOptOut],
                                                       optOutUrl: "broker.com")

        // Then
        XCTAssertTrue(profileMatch.hasMatchingRecordOnParentBroker)
    }

    // MARK: - `profileMatches` Broker OptOut URL & Name tests

    func testProfileMatches_optOutUrlAndBrokerNameForChildBroker() {
        // Given
        let extractedProfile = ExtractedProfile(id: 1, name: "Sample Name", profileUrl: "profile.com")

        let childBroker = BrokerProfileQueryData.mock(
            dataBrokerName: "ChildBroker",
            url: "child.com",
            parentURL: "parent.com",
            optOutUrl: "child.com/optout",
            extractedProfile: extractedProfile
        )

        let parentBroker = BrokerProfileQueryData.mock(
            dataBrokerName: "ParentBroker",
            url: "parent.com",
            optOutUrl: "parent.com/optout",
            extractedProfile: extractedProfile
        )

        // When
        let results = DBPUIDataBrokerProfileMatch.profileMatches(from: [childBroker, parentBroker])

        // Then
        XCTAssertEqual(results.count, 2)

        let childProfile = results.first { $0.dataBroker.name == "ChildBroker" }
        XCTAssertEqual(childProfile?.dataBroker.optOutUrl, "child.com/optout")
    }

    func testProfileMatches_optOutUrlAndBrokerNameForParentBroker() {
        // Given
        let extractedProfile = ExtractedProfile(id: 1, name: "Sample Name", profileUrl: "profile.com")

        let childBroker = BrokerProfileQueryData.mock(
            dataBrokerName: "ChildBroker",
            url: "child.com",
            parentURL: "parent.com",
            optOutUrl: "parent.com/optout",
            extractedProfile: extractedProfile
        )

        let parentBroker = BrokerProfileQueryData.mock(
            dataBrokerName: "ParentBroker",
            url: "parent.com",
            optOutUrl: "parent.com/optout",
            extractedProfile: extractedProfile
        )

        // When
        let results = DBPUIDataBrokerProfileMatch.profileMatches(from: [childBroker, parentBroker])

        // Then
        XCTAssertEqual(results.count, 2)

        let childProfile = results.first { $0.dataBroker.name == "ChildBroker" }
        XCTAssertEqual(childProfile?.dataBroker.optOutUrl, "parent.com/optout")
    }
}
