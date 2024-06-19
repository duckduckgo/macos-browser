//
//  PIRIntegrationTests.swift
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
import LoginItems
@testable import DuckDuckGo_Privacy_Browser

final class PIRIntegrationTests: XCTestCase {

    static let dbpBackgroundAgent = LoginItem(bundleId: Bundle.main.dbpBackgroundAgentBundleId, defaults: .dbp, log: .dbp)

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() async throws {

//        let launchedExpectation = expectation(description: "test")
        let profileExpectation = expectation(description: "test")

        let loginItemsManager = LoginItemsManager()
        let loginItemInterface = DataBrokerProtectionManager.shared.loginItemInterface

        loginItemsManager.enableLoginItems([LoginItem.dbpBackgroundAgent], log: .dbp)

        try await Task.sleep(nanoseconds: 1_000_000_000)
        try await Task.sleep(nanoseconds: 1_000_000_000)
        try await Task.sleep(nanoseconds: 1_000_000_000)
        try await Task.sleep(nanoseconds: 1_000_000_000)
        try await Task.sleep(nanoseconds: 1_000_000_000)

//        loginItemInterface.appLaunched {
//            launchedExpectation.fulfill()
//        }

//        await fulfillment(of: [launchedExpectation], timeout: 30)

        try await Task.sleep(nanoseconds: 1_000_000_000)

        DataBrokerProtectionManager.shared.loginItemInterface.profileSaved {
            profileExpectation.fulfill()
        }

        await fulfillment(of: [profileExpectation], timeout: 30)
    }
}
