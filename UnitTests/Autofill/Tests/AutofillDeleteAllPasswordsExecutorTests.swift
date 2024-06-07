//
//  AutofillDeleteAllPasswordsExecutorTests.swift
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

import BrowserServicesKit
import DDGSync
import XCTest
@testable import DuckDuckGo_Privacy_Browser

final class AutofillDeleteAllPasswordsExecutorTests: XCTestCase {

    private var sut: AutofillDeleteAllPasswordsExecutor!
    private let mockAuthenticator = UserAuthenticatorMock()
    private var secureVault: MockSecureVault<MockDatabaseProvider>!
    private let scheduler = CapturingScheduler()
    private var syncService: DDGSyncing!

    override func setUpWithError() throws {
        secureVault = try MockSecureVaultFactory.makeVault(reporter: nil)
        syncService = MockDDGSyncing(authState: .inactive, scheduler: scheduler, isSyncInProgress: false)
        sut = .init(userAuthenticator: mockAuthenticator, secureVault: secureVault, syncService: syncService)
    }

    func testExecuteCallsAuthenticate() async throws {
        // Given
        let expectation = expectation(description: "called authenticate")
        XCTAssertFalse(mockAuthenticator.didCallAuthenticate)

        // When
        sut.execute {
            expectation.fulfill()
        }

        // Then
        await fulfillment(of: [expectation], timeout: 3)
        XCTAssertTrue(mockAuthenticator.didCallAuthenticate)
    }

    func testExecuteCallsDeletesAllFromVault() async throws {
        // Given
        let expectation = expectation(description: "called delete all from vault")
        secureVault.addWebsiteCredentials(identifiers: [1])
        XCTAssert(secureVault.storedCredentials.count == 1)

        // When
        sut.execute {
            expectation.fulfill()
        }

        // Then
        await fulfillment(of: [expectation], timeout: 3)
        XCTAssert(secureVault.storedCredentials.isEmpty)
    }

    func testExecuteCallsNotifyDataChanged() async throws {
        // Given
        let expectation = expectation(description: "called sync immediately")
        XCTAssertFalse(scheduler.notifyDataChangedCalled)

        // When
        sut.execute {
            expectation.fulfill()
        }

        // Then
        await fulfillment(of: [expectation], timeout: 3)
        XCTAssertTrue(scheduler.notifyDataChangedCalled)
    }
}
