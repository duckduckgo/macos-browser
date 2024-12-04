//
//  OnboardingNavigationDelegateTests.swift
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
import Onboarding
@testable import DuckDuckGo_Privacy_Browser

final class OnboardingNavigationDelegateTests: XCTestCase {

    var tab: Tab!

    @MainActor
    override func setUpWithError() throws {
        try super.setUpWithError()
        tab = Tab()
    }

    override func tearDownWithError() throws {
        tab = nil
        try super.tearDownWithError()
    }

    func testNavigateToUrlLoadsSiteInCurrentTab() throws {
        // GIVEN
        let expectedUrl = try XCTUnwrap(URL(string: "some.url"))
        let expectation = self.expectation(description: "Wait for url to load in current tab")

        // WHEN
        tab.navigateFromOnboarding(to: expectedUrl)

        // THEN
        pollForCondition(
            condition: { self.tab.url == expectedUrl },
            expectation: expectation,
            timeout: 3.0, // Timeout of 3 seconds
            retryInterval: 0.1 // Check every 0.1 seconds
        )
        wait(for: [expectation], timeout: 3.0)
    }

    func testSearchForQueryLoadsQueryInCurrentTab() throws {
        // GIVEN
        let query = "Some query"
        let expectedUrl = try XCTUnwrap(URL.makeSearchUrl(from: query))
        let expectation = self.expectation(description: "Wait for query to load in current tab")

        // WHEN
        tab.searchFromOnboarding(for: query)

        // THEN
        pollForCondition(
            condition: { self.tab.url == expectedUrl },
            expectation: expectation,
            timeout: 3.0,
            retryInterval: 0.1
        )
        wait(for: [expectation], timeout: 3.0)
    }

    private func pollForCondition(condition: @escaping () -> Bool,
                                  expectation: XCTestExpectation,
                                  timeout: TimeInterval,
                                  retryInterval: TimeInterval) {
        let deadline = DispatchTime.now() + retryInterval
        DispatchQueue.main.asyncAfter(deadline: deadline) {
            if condition() {
                // Condition is met, fulfill the expectation
                expectation.fulfill()
            } else if timeout <= 0 {
                // Timeout expired, do nothing (test will fail due to wait timeout)
            } else {
                // Try again, reduce timeout by retryInterval
                self.pollForCondition(condition: condition,
                                      expectation: expectation,
                                      timeout: timeout - retryInterval,
                                      retryInterval: retryInterval)
            }
        }
    }

}
