//
//  PIRScanIntegrationTests.swift
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

@testable import DataBrokerProtection
import LoginItems
import XCTest
import PixelKitTestingUtilities
@testable import DuckDuckGo_Privacy_Browser
@testable import PixelKit

final class PIRScanIntegrationTests: XCTestCase {

    var loginItemsManager: LoginItemsManager!
    var pirProtectionManager = DataBrokerProtectionManager.shared
    var communicationLayer: DBPUICommunicationLayer!
    var communicationDelegate: DBPUICommunicationDelegate!
    var viewModel: DBPUIViewModel!
    let testUserDefault = UserDefaults(suiteName: #function)!

    private func fulfillExpecation(_ expectation: XCTestExpectation, whenCondition condition: () async -> Bool) async {
        while await !condition() { }
        expectation.fulfill()
    }

    private func awaitFulfillment(of expectation: XCTestExpectation, withTimeout timeout: TimeInterval, whenCondition condition: @escaping () async -> Bool) async {
        Task {
            await fulfillExpecation(expectation, whenCondition: condition)
        }

        await fulfillment(of: [expectation], timeout: timeout)
    }

    typealias PixelExpectation = (pixel: DataBrokerProtectionPixels, expectation: XCTestExpectation)

    private func pixelKitToTest(_ pixelExpectations: [PixelExpectation]) -> PixelKit {
        return PixelKit(dryRun: false,
                        appVersion: "1.0.0",
                        defaultHeaders: [:],
                        defaults: testUserDefault) { pixelName, _, _, _, _, _ in
            for pixelExpectation in pixelExpectations where pixelName.hasPrefix(pixelExpectation.pixel.name) {
                pixelExpectation.expectation.fulfill()
            }
        }
    }

    override func setUpWithError() throws {
        loginItemsManager = LoginItemsManager()
        loginItemsManager.disableLoginItems([LoginItem.dbpBackgroundAgent])
        loginItemsManager.enableLoginItems([LoginItem.dbpBackgroundAgent], log: .dbp)

        communicationLayer = DBPUICommunicationLayer(webURLSettings: DataBrokerProtectionWebUIURLSettings(UserDefaults.standard))
        communicationLayer.delegate = pirProtectionManager.dataManager.cache

        communicationDelegate = pirProtectionManager.dataManager.cache

        viewModel = DBPUIViewModel(dataManager: pirProtectionManager.dataManager, agentInterface: pirProtectionManager.loginItemInterface, webUISettings: DataBrokerProtectionWebUIURLSettings(UserDefaults.standard))

        pirProtectionManager.dataManager.cache.scanDelegate = viewModel

        let database = pirProtectionManager.dataManager.database
        try database.deleteProfileData()
    }

    override func tearDown() async throws {
        try pirProtectionManager.dataManager.database.deleteProfileData()
        loginItemsManager.disableLoginItems([LoginItem.dbpBackgroundAgent])
    }

    /*
     This test shows is where I'm developing everything
     EVERYTHING
     */
    func testWhenProfileIsSaved_ThenEVERYTHINGHAPPENS() async throws {
        // Given
        let dataManager = pirProtectionManager.dataManager
        let database = dataManager.database
        let cache = pirProtectionManager.dataManager.cache
        try database.deleteProfileData()
        XCTAssert(try database.fetchAllBrokerProfileQueryData().isEmpty)

        /*
         // When
         1/ We save a profile
         */

        cache.profile = mockProfile
        Task { @MainActor in
            _ = try await communicationLayer.saveProfile(params: [], original: WKScriptMessage())
        }

        // Then
        let profileSavedExpectation = expectation(description: "Profile saved in DB")
        let profileQueriesCreatedExpectation = expectation(description: "Profile queries created")

        await awaitFulfillment(of: profileSavedExpectation,
                               withTimeout: 3,
                               whenCondition: {
            try! database.fetchProfile() != nil })
        await awaitFulfillment(of: profileQueriesCreatedExpectation,
                               withTimeout: 3,
                               whenCondition: {
            try! database.fetchAllBrokerProfileQueryData().count > 0 })

        /*
        2/ We scan brokers
        */

        let schedulerStartsExpectation = expectation(description: "Scheduler starts")

        await awaitFulfillment(of: schedulerStartsExpectation,
                               withTimeout: 10,
                               whenCondition: {
            try! self.pirProtectionManager.dataManager.prepareBrokerProfileQueryDataCache()
            return await self.communicationDelegate.getBackgroundAgentMetadata().lastStartedSchedulerOperationTimestamp == nil
        })

        let metaData = await communicationDelegate.getBackgroundAgentMetadata()
        XCTAssertNotNil(metaData.lastStartedSchedulerOperationBrokerUrl)

        /*
        3/ We find and save extracted profiles
        */
        let extractedProfilesFoundExpectation = expectation(description: "Extracted profiles found and saved in DB")

        await awaitFulfillment(of: extractedProfilesFoundExpectation,
                               withTimeout: 60,
                               whenCondition: {
            let queries = try! database.fetchAllBrokerProfileQueryData()
            let brokerIDs = queries.compactMap { $0.dataBroker.id }
            let extractedProfiles = brokerIDs.flatMap { try! database.fetchExtractedProfiles(for: $0) }
            return extractedProfiles.count > 0
        })

        /*
         4/ We create opt out jobs
         */
        let optOutJobsCreatedExpectation = expectation(description: "Opt out jobs created")

        await awaitFulfillment(of: optOutJobsCreatedExpectation,
                               withTimeout: 10,
                               whenCondition: {
            let queries = try! database.fetchAllBrokerProfileQueryData()
            let optOutJobs = queries.flatMap { $0.optOutJobData }
            return optOutJobs.count > 0
        })
    }
}

private extension PIRScanIntegrationTests {
    var mockProfile: DataBrokerProtectionProfile {
        // Use the current year to calculate age, since the fake broker is static (so will always list "63")
        let year = Calendar(identifier: .gregorian).component(.year, from: Date())
        let birthYear = year - 63

        return .init(names: [.init(firstName: "John", lastName: "Smith", middleName: "G")],
                     addresses: [.init(city: "Dallas", state: "TX")],
                     phones: [],
                     birthYear: birthYear)
    }
}
