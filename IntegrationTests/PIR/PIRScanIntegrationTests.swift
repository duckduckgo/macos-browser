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
import BrowserServicesKit
import LoginItems
import XCTest
import PixelKitTestingUtilities
import Combine
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
        let task = Task {
            await fulfillExpecation(expectation, whenCondition: condition)
        }

        await fulfillment(of: [expectation], timeout: timeout)
        task.cancel()
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
        continueAfterFailure = false

        loginItemsManager = LoginItemsManager()
        loginItemsManager.disableLoginItems([LoginItem.dbpBackgroundAgent])
        loginItemsManager.enableLoginItems([LoginItem.dbpBackgroundAgent])

        communicationLayer = DBPUICommunicationLayer(webURLSettings:
                                                        DataBrokerProtectionWebUIURLSettings(UserDefaults.standard), privacyConfig: PrivacyConfigurationManagingMock())
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
     interface UserProfile {
       firstName: string
       lastName: string
       age: number
       city: string
       state: string
     }

     interface UserProfileWithId extends UserProfile {
       id: number
     }

     POST URL/profiles

     request payload:
     UserProfile
     */

    struct UserProfile: Codable {
        let firstName: String
        let lastName: String
        let age: Int
        let city: String
        let state: String
    }

    struct ReturnedUserProfile: Codable {
        let id: Int
        let profileUrl: String
        let firstName: String
        let lastName: String
        let age: Int
        let city: String
        let state: String
    }

    func mockUserProfile() -> UserProfile {
        return UserProfile(firstName: "John", lastName: "Smith", age: 63, city: "Dallas", state: "TX")
    }

    // A useful function for debugging responses from the fake broker
    func prettyPrintJSONData(_ data: Data) {
        if let json = try? JSONSerialization.jsonObject(with: data, options: .mutableContainers),
           let jsonData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) {
            print(String(decoding: jsonData, as: UTF8.self))
        } else {
            print("json data malformed")
        }
    }

    func validateFakeBrokerResponse(responseData: Data, response: URLResponse) {
        let httpResponse = response as! HTTPURLResponse
        if httpResponse.statusCode != 200 {
            prettyPrintJSONData(responseData)
            XCTFail("Response code indidcates failure. Check the printed response data above (if expected json)")
        }
    }

    let fakeBrokerAPIAddress = "http://localhost:3001/api/"

    func deleteAllProfilesOnFakeBroker() async {
        let deleteProfilesURL = URL(string: fakeBrokerAPIAddress + "profiles")!
        var deleteRequest = URLRequest(url: deleteProfilesURL)
        deleteRequest.httpMethod = "DELETE"

        let (responseData, response) = try! await URLSession.shared.data(for: deleteRequest)
        validateFakeBrokerResponse(responseData: responseData, response: response)
    }

    func createProfileOnFakeBroker(_ profile: UserProfile) async -> ReturnedUserProfile {
        let url = URL(string: fakeBrokerAPIAddress + "profiles")!
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        let encoder = JSONEncoder()
        let data = try! encoder.encode(profile)
        request.httpBody = data

        let (responseData, response) = try! await URLSession.shared.data(for: request)
        validateFakeBrokerResponse(responseData: responseData, response: response)

        let decoder = JSONDecoder()
        return try! decoder.decode(ReturnedUserProfile.self, from: responseData)
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
        XCTAssertTrue(LoginItem.dbpBackgroundAgent.isRunning)
    }

    /*
     This test shows is where I'm developing everything
     EVERYTHING
     */
    func testWhenProfileIsSaved_ThenEVERYTHINGHAPPENS() async throws {
        // Given
        // Local state set up
        let dataManager = pirProtectionManager.dataManager
        let database = dataManager.database
        let cache = pirProtectionManager.dataManager.cache
        try database.deleteProfileData()
        XCTAssert(try database.fetchAllBrokerProfileQueryData().isEmpty)

        // Fake broker set up
        await deleteAllProfilesOnFakeBroker()

        let mockUserProfile = mockUserProfile()
        let returnedUserProfile = await createProfileOnFakeBroker(mockUserProfile)

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
            try! database.fetchAllBrokerProfileQueryData().count > 0
        })
        print("Stage 1 passed: We save a profile")

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
        print("Stage 2 passed: We scan brokers")

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

        let queries3 = try! database.fetchAllBrokerProfileQueryData()
        let brokerIDs = queries3.compactMap { $0.dataBroker.id }
        let extractedProfiles = brokerIDs.flatMap { try! database.fetchExtractedProfiles(for: $0) }
        //print(extractedProfiles)
        print("Stage 3 passed: We find and save extracted profiles")

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
        print("Stage 4 passed: We create opt out jobs")

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
        print("Stage 5.1 passed: We start running the opt out jobs")

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

        print("Stage 5 passed: We finish running the opt out jobs")

        /*
        6/ The BE service receives the email
         The fake broker currently doesn't, but will eventually send this,
         so there's nothing to do on the client to test this step.
         */

        /*
        7/ The app polls the backend service for the link
         8/ We visit the confirmation link

         Since the fake broker doesn't send emails at the moment, we can't actually test these steps
         Once it does, we can use the below code.

          The current only way we can check these from the app is through pixels
          Not great to tie to pixels. Better to check from fake broker we visited confirmation page correctly
         */
        /*
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
         */
        print("Stages 6-8 skipped: Fake brokerd doesn't support sending emails")

        /*
        9/ We confirm the opt out through a scan
         */
        //TODO would be good to read from fake broker directly too

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
        print("Stage 9 passed: We confirm the opt out through a scan")
    }
}

private extension PIRScanIntegrationTests {
    var mockProfile: DataBrokerProtectionProfile {
        // Use the current year to calculate age, since the fake broker is static (so will always list "63")
        let year = Calendar(identifier: .gregorian).component(.year, from: Date())
        let birthYear = year - 63

        return .init(names: [.init(firstName: "John", lastName: "Smith")],
                     addresses: [.init(city: "Dallas", state: "TX")],
                     phones: [],
                     birthYear: birthYear)
    }

    final class PrivacyConfigurationManagingMock: PrivacyConfigurationManaging {
        var currentConfig: Data = Data()

        var updatesPublisher: AnyPublisher<Void, Never> = .init(Just(()))

        var privacyConfig: BrowserServicesKit.PrivacyConfiguration = PrivacyConfigurationMock()

        var internalUserDecider: InternalUserDecider = DefaultInternalUserDecider(store: InternalUserDeciderStoreMock())

        func reload(etag: String?, data: Data?) -> PrivacyConfigurationManager.ReloadResult {
            .downloaded
        }
    }

    final class PrivacyConfigurationMock: PrivacyConfiguration {
        var identifier: String = "mock"
        var version: String? = "123456789"

        var userUnprotectedDomains = [String]()

        var tempUnprotectedDomains = [String]()

        var trackerAllowlist = BrowserServicesKit.PrivacyConfigurationData.TrackerAllowlist(entries: [String: [PrivacyConfigurationData.TrackerAllowlist.Entry]](), state: "mock")

        func isEnabled(featureKey: BrowserServicesKit.PrivacyFeature, versionProvider: BrowserServicesKit.AppVersionProvider) -> Bool {
            false
        }

        func stateFor(featureKey: BrowserServicesKit.PrivacyFeature, versionProvider: BrowserServicesKit.AppVersionProvider) -> BrowserServicesKit.PrivacyConfigurationFeatureState {
            .disabled(.disabledInConfig)
        }

        func isSubfeatureEnabled(_ subfeature: any PrivacySubfeature, versionProvider: BrowserServicesKit.AppVersionProvider) -> Bool {
            false
        }

        func stateFor(_ subfeature: any PrivacySubfeature, versionProvider: BrowserServicesKit.AppVersionProvider, randomizer: (Range<Double>) -> Double) -> BrowserServicesKit.PrivacyConfigurationFeatureState {
            .disabled(.disabledInConfig)
        }

        func exceptionsList(forFeature featureKey: BrowserServicesKit.PrivacyFeature) -> [String] {
            [String]()
        }

        func isFeature(_ feature: BrowserServicesKit.PrivacyFeature, enabledForDomain: String?) -> Bool {
            false
        }

        func isProtected(domain: String?) -> Bool {
            false
        }

        func isUserUnprotected(domain: String?) -> Bool {
            false
        }

        func isTempUnprotected(domain: String?) -> Bool {
            false
        }

        func isInExceptionList(domain: String?, forFeature featureKey: BrowserServicesKit.PrivacyFeature) -> Bool {
            false
        }

        func settings(for feature: BrowserServicesKit.PrivacyFeature) -> BrowserServicesKit.PrivacyConfigurationData.PrivacyFeature.FeatureSettings {
            [String: Any]()
        }

        func userEnabledProtection(forDomain: String) {

        }

        func userDisabledProtection(forDomain: String) {

        }

        func isSubfeatureEnabled(_ subfeature: any BrowserServicesKit.PrivacySubfeature, versionProvider: BrowserServicesKit.AppVersionProvider, randomizer: (Range<Double>) -> Double) -> Bool {
            false
        }
    }
}
