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
@testable import DuckDuckGo_Privacy_Browser

final class PIRScanIntegrationTests: XCTestCase {

    var loginItemsManager: LoginItemsManager!
    var pirProtectionManager = DataBrokerProtectionManager.shared
    var communicationLayer: DBPUICommunicationLayer!
    var communicationDelegate: DBPUICommunicationDelegate!
    var viewModel: DBPUIViewModel!

    override func setUpWithError() throws {
        loginItemsManager = LoginItemsManager()
        loginItemsManager.disableLoginItems([LoginItem.dbpBackgroundAgent])
        loginItemsManager.enableLoginItems([LoginItem.dbpBackgroundAgent], log: .dbp)

        communicationLayer = DBPUICommunicationLayer(webURLSettings: DataBrokerProtectionWebUIURLSettings(UserDefaults.standard))
        communicationLayer.delegate = pirProtectionManager.dataManager.cache

        communicationDelegate = pirProtectionManager.dataManager.cache

        viewModel = DBPUIViewModel(dataManager: pirProtectionManager.dataManager, agentInterface: pirProtectionManager.loginItemInterface, webUISettings: DataBrokerProtectionWebUIURLSettings(UserDefaults.standard))

        pirProtectionManager.dataManager.cache.scanDelegate = viewModel
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
        XCTAssertTrue(LoginItem.dbpBackgroundAgent.isRunning)
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
}

private extension PIRScanIntegrationTests {
    var mockProfile: DataBrokerProtectionProfile {
        .init(names: [.init(firstName: "Dax", lastName: "Duck")], addresses: [.init(city: "Duckville", state: "Duck State")], phones: [], birthYear: 1981)
    }
}
