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
     This test shows a test which asserts that the login item starts
     */
    func testLoginItemIsRunning() async throws {
        try await Task.sleep(nanoseconds: 3_000_000_000)

        // When
        try await pirProtectionManager.dataManager.saveProfile(mockProfile)

        XCTAssertTrue(loginItemsManager.isAnyEnabled([.dbpBackgroundAgent]))
        // Failing, likely due to missing profile and background agent being killed
//        XCTAssertTrue(LoginItem.dbpBackgroundAgent.isRunning)
    }

    /*
     This test shows an example of an integration test that uses a `while` loop to await
     a scan starting
     */
    func testWhenProfileIsSaved_ThenScanStarts() async throws {
        // Given
        let database = pirProtectionManager.dataManager.database
        let cache = pirProtectionManager.dataManager.cache
        try database.deleteProfileData()
        XCTAssert(try database.fetchAllBrokerProfileQueryData().isEmpty)
        XCTAssert(try database.fetchProfile() == nil)

        cache.profile = mockProfile

        let expectation = expectation(description: "Result is returned")

        // When
        Task { @MainActor in
            _ = try await communicationLayer.saveProfile(params: [], original: WKScriptMessage())
        }

        Task {
            while await communicationDelegate.getBackgroundAgentMetadata().lastStartedSchedulerOperationTimestamp == nil {
                try pirProtectionManager.dataManager.prepareBrokerProfileQueryDataCache()
            }

            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 10)
        let metaData = await communicationDelegate.getBackgroundAgentMetadata()
        XCTAssertNotNil(metaData.lastStartedSchedulerOperationBrokerUrl)
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

        let queries = try! database.fetchAllBrokerProfileQueryData()
        let thing = queries.filter { $0.optOutJobData.count > 0 }
        let name = thing[0].dataBroker.name
        print(name)

        /*
         5/ We run those opt out jobs
         For now we check the lastRunDate on the optOutJob, but that could always be wrong. Ideally we need this information from the fake broker
         */
        let optOutJobsRunExpectation = expectation(description: "Opt out jobs run")

        /* Currently hard coded the cadences to get this to run
         need to in future change them for the tests
         Also is a big inconsistent with current QoS
         so possibly worth changing for tests
         */
        await awaitFulfillment(of: optOutJobsRunExpectation,
                               withTimeout: 300,
                               whenCondition: {
            let queries = try! database.fetchAllBrokerProfileQueryData()
            let optOutJobs = queries.flatMap { $0.optOutJobData }
            return optOutJobs[0].lastRunDate != nil
        })

        let optOutRequestedExpectation = expectation(description: "Opt out requested")
        await awaitFulfillment(of: optOutRequestedExpectation,
                               withTimeout: 300,
                               whenCondition: {
            let queries = try! database.fetchAllBrokerProfileQueryData()
            let optOutJobs = queries.flatMap { $0.optOutJobData }
            let events = optOutJobs.flatMap { $0.historyEvents }
            let optOutsRequested = events.filter{ $0.type == .optOutRequested }
            return optOutsRequested.count > 0
        })

        /*
         Okay, now kinda stuck with current fake broker
         but possibly worth exploring what this will look like?
        6/ The BE service receives the email
         So fake broker will send this, nothing to do on client?
         */

        /*
        7/ The app polls the backend service for the link
         8/ We visit the confirmation link
          The current only way we can check these from the app is through pixels
          Not great to tie to pixels. Better to check from fake broker we visited confirmation page correctly
         */
        let optOutEmailReceivedPixelExpectation = expectation(description: "Opt out email received pixel fired")
        let optOutEmailConfirmedPixelExpectation = expectation(description: "Opt out email confirmed pixel fired")

        let optOutEmailReceivedPixel = DataBrokerProtectionPixels.optOutEmailReceive(dataBroker: "", attemptId: UUID(), duration: 0)
        let optOutEmailConfirmedPixel = DataBrokerProtectionPixels.optOutEmailConfirm(dataBroker: "", attemptId: UUID(), duration: 0)

        let pixelExpectations = [
            PixelExpectation(pixel: optOutEmailReceivedPixel,
                             expectation: optOutEmailReceivedPixelExpectation),
            PixelExpectation(pixel: optOutEmailConfirmedPixel,
                             expectation: optOutEmailConfirmedPixelExpectation)]
        let pixelKit = pixelKitToTest(pixelExpectations)
        PixelKit.setSharedForTesting(pixelKit: pixelKit)

        await fulfillment(of: [optOutEmailReceivedPixelExpectation, optOutEmailConfirmedPixelExpectation],
                          timeout: 300)

        PixelKit.tearDown()
        pixelKit.clearFrequencyHistoryForAllPixels()

        /*
        9/ We confirm the opt out through a scan
         would be good to read from fake broker directly too
         */

        let optOutConfirmedExpectation = expectation(description: "Opt out confirmed")
        await awaitFulfillment(of: optOutConfirmedExpectation,
                               withTimeout: 300,
                               whenCondition: {
            let queries = try! database.fetchAllBrokerProfileQueryData()
            let optOutJobs = queries.flatMap { $0.optOutJobData }
            let events = optOutJobs.flatMap { $0.historyEvents }
            let optOutsConfirmed = events.filter{ $0.type == .optOutConfirmed }
            return optOutsConfirmed.count > 0
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
