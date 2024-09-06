//
//  DataBrokerProtectionDataManagingTests.swift
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
@testable import DataBrokerProtection

final class DataBrokerProtectionDataManagingTests: XCTestCase {

    private var sut: DataBrokerProtectionDataManaging!
    private var mockDatabase: MockDatabase!
    private var mockDBPProfileSavedNotifier: MockDBPProfileSavedNotifier!

    override func setUpWithError() throws {
        mockDatabase = MockDatabase()
        mockDBPProfileSavedNotifier = MockDBPProfileSavedNotifier()
        sut = DataBrokerProtectionDataManager(database: mockDatabase,
                                              profileSavedNotifier: mockDBPProfileSavedNotifier,
                                              pixelHandler: MockPixelHandler())
    }

    func testWhenNoMatches_thenZeroMatchesFoundCountIsReturned() throws {
        // Given
        mockDatabase.brokerProfileQueryDataToReturn = []

        // When
        let matchesCount = try sut.matchesFoundCount()

        // Then
        XCTAssertEqual(matchesCount, 0)
    }

    func testWhenMultipleProfilesAndMirrorSites_thenCorrectMatchesFoundCountIsReturned() throws {
        // Given
        mockDatabase.brokerProfileQueryDataToReturn = mockQueryData

        // When
        let matchesCount = try sut.matchesFoundCount()

        // Then
        // We expect 6 matches:
         // - 1 extracted profile + 2 mirror sites for Broker A (3 total)
         // - Broker B is deprecated, so it should be skipped (0 total)
         // - 1 extracted profile + 1 mirror site for Broker C (2 total)
         // - 1 more extracted profile for Broker C (1 total)
         // - Total = 3 + 0 + 2 + 1 = 6
        XCTAssertEqual(matchesCount, 6)
    }

    func testWhenAllBrokersAreDeprecated_thenZeroMatchesFoundCountIsReturned() throws {
        // Given
        let deprecatedBrokers = [
            BrokerProfileQueryData.mock(deprecated: true),
            BrokerProfileQueryData.mock(deprecated: true)
        ]
        mockDatabase.brokerProfileQueryDataToReturn = deprecatedBrokers

        // When
        let matchesCount = try sut.matchesFoundCount()

        // Then
        XCTAssertEqual(matchesCount, 0)
    }

    func testWhenNoExtractedProfilesButMirrorSitesExist_thenCorrectMirrorSiteCountIsReturned() throws {
        // Given
        let brokersWithOnlyMirrorSites = [
            BrokerProfileQueryData.mock(
                extractedProfile: nil,
                mirrorSites: [
                    MirrorSite(name: "Mirror 1", url: "https://mirror1.com", addedAt: Date(), removedAt: nil)
                ]
            )
        ]
        mockDatabase.brokerProfileQueryDataToReturn = brokersWithOnlyMirrorSites

        // When
        let matchesCount = try sut.matchesFoundCount()

        // Then
        // 1 mirror site should be counted
        XCTAssertEqual(matchesCount, 1)
    }

    func testWhenMirrorSitesAreRemoved_thenTheyAreNotCounted() throws {
        // Given
        let brokerWithRemovedMirrorSites = BrokerProfileQueryData.mock(
            extractedProfile: nil,
            mirrorSites: [
                MirrorSite(name: "Mirror 1", url: "https://mirror1.com", addedAt: Date(), removedAt: Date())
            ]
        )
        mockDatabase.brokerProfileQueryDataToReturn = [brokerWithRemovedMirrorSites]

        // When
        let matchesCount = try sut.matchesFoundCount()

        // Then
        // No profiles and removed mirror site, so count should be 0
        XCTAssertEqual(matchesCount, 0)
    }

    func testWhenProfileIsSaved_thenNotifierIsCalled() async throws {
        // Given
        let profile = mockProfile
        mockDatabase.saveResult = .success(())

        // When
        try await sut.saveProfile(profile)

        // Then
        XCTAssertTrue(mockDBPProfileSavedNotifier.didCallPostProfileSavedNotificationIfPermitted)
    }

    func testWhenSavingProfileFails_thenNotifierIsNotCalled() async {
        // Given
        let profile = mockProfile
        mockDatabase.saveResult = .failure(MockDatabase.MockError.saveFailed)

        // When
        do {
            try await sut.saveProfile(profile)
            XCTFail("Expected saveProfile to throw an error but it succeeded.")
        } catch {}

        // Then
        XCTAssertFalse(mockDBPProfileSavedNotifier.didCallPostProfileSavedNotificationIfPermitted)
    }
}

private extension DataBrokerProtectionDataManagingTests {

    var mockProfile: DataBrokerProtectionProfile {
        let name = DataBrokerProtectionProfile.Name(
            firstName: "John",
            lastName: "Doe",
            middleName: "M",
            suffix: "Jr"
        )

        let address = DataBrokerProtectionProfile.Address(
            city: "New York",
            state: "NY",
            street: "123 Main St",
            zipCode: "10001"
        )

        let phones = ["123-456-7890"]

        let birthYear = 1985

        let profile = DataBrokerProtectionProfile(
            names: [name],
            addresses: [address],
            phones: phones,
            birthYear: birthYear
        )

        return profile
    }

    var mockQueryData: [BrokerProfileQueryData] {
        [
            // First item: Active broker with 1 extracted profile and 2 mirror sites
            BrokerProfileQueryData.mock(
                dataBrokerName: "Broker A",
                url: "https://broker-a.com",
                extractedProfile: ExtractedProfile(
                    id: 1,
                    name: "John Doe",
                    alternativeNames: nil,
                    addressFull: nil,
                    addresses: nil,
                    phoneNumbers: nil,
                    relatives: nil,
                    profileUrl: nil,
                    reportId: nil,
                    age: nil,
                    email: nil,
                    removedDate: nil,
                    identifier: "id1"
                ), scanHistoryEvents: [
                    HistoryEvent(
                        extractedProfileId: 1,
                        brokerId: 1,
                        profileQueryId: 1,
                        type: .scanStarted,
                        date: Date()
                    )
                ], mirrorSites: [
                    MirrorSite(name: "Mirror 1", url: "https://mirror1.com", addedAt: Date(), removedAt: nil),
                    MirrorSite(name: "Mirror 2", url: "https://mirror2.com", addedAt: Date(), removedAt: nil)
                ],
                deprecated: false
            ),

            // Second item: Deprecated broker with no matches
            BrokerProfileQueryData.mock(
                dataBrokerName: "Broker B",
                url: "https://broker-b.com",
                extractedProfile: nil, scanHistoryEvents: [
                    HistoryEvent(
                        extractedProfileId: nil,
                        brokerId: 2,
                        profileQueryId: 2,
                        type: .scanStarted,
                        date: Date()
                    )
                ], mirrorSites: [],
                deprecated: true
            ),

            // Third item: Active broker with 2 extracted profiles and 1 mirror site
            BrokerProfileQueryData.mock(
                dataBrokerName: "Broker C",
                url: "https://broker-c.com",
                extractedProfile: ExtractedProfile(
                    id: 2,
                    name: "Alice",
                    alternativeNames: nil,
                    addressFull: nil,
                    addresses: nil,
                    phoneNumbers: nil,
                    relatives: nil,
                    profileUrl: nil,
                    reportId: nil,
                    age: nil,
                    email: nil,
                    removedDate: nil,
                    identifier: "id2"
                ), scanHistoryEvents: [
                    HistoryEvent(
                        extractedProfileId: 2,
                        brokerId: 3,
                        profileQueryId: 3,
                        type: .scanStarted,
                        date: Date()
                    )
                ], mirrorSites: [
                    MirrorSite(name: "Mirror 3", url: "https://mirror3.com", addedAt: Date(), removedAt: nil)
                ],
                deprecated: false
            ),

            // Fourth item: Another extracted profile for Broker C, but no mirror site
            BrokerProfileQueryData.mock(
                dataBrokerName: "Broker C",
                url: "https://broker-c.com",
                extractedProfile: ExtractedProfile(
                    id: 3,
                    name: "Bob",
                    alternativeNames: nil,
                    addressFull: nil,
                    addresses: nil,
                    phoneNumbers: nil,
                    relatives: nil,
                    profileUrl: nil,
                    reportId: nil,
                    age: nil,
                    email: nil,
                    removedDate: nil,
                    identifier: "id3"
                ), scanHistoryEvents: [
                    HistoryEvent(
                        extractedProfileId: 3,
                        brokerId: 3,
                        profileQueryId: 3,
                        type: .optOutConfirmed,
                        date: Date()
                    )
                ], mirrorSites: [],
                deprecated: false
            )
        ]
    }
}
