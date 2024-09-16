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
        let profileMatch = DBPUIDataBrokerProfileMatch(extractedProfile: extractedProfile,
                                                       optOutJobData: optOut,
                                                       dataBrokerName: "doesn't matter for the test",
                                                       databrokerURL: "see above")

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
        let profileMatch = DBPUIDataBrokerProfileMatch(extractedProfile: extractedProfile,
                                                       optOutJobData: optOut,
                                                       dataBrokerName: "doesn't matter for the test",
                                                       databrokerURL: "see above")

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
        let profileMatch = DBPUIDataBrokerProfileMatch(extractedProfile: extractedProfile,
                                                       optOutJobData: optOut,
                                                       dataBrokerName: "doesn't matter for the test",
                                                       databrokerURL: "see above")

        // Then
        XCTAssertEqual(profileMatch.foundDate, foundEventDate2.timeIntervalSince1970)
        XCTAssertEqual(profileMatch.optOutSubmittedDate, submittedEventDate2.timeIntervalSince1970)
    }

}
