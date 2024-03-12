//
//  NavigationBarPopoversTests.swift
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
@testable import DuckDuckGo_Privacy_Browser
import XCTest

#if NETWORK_PROTECTION
import NetworkProtection
import NetworkProtectionIPC
#endif

private final class MockNSPopoverDelegate: NSObject, NSPopoverDelegate {}

final class NavigationBarPopoversTests: XCTestCase {

    private var sut: NavigationBarPopovers!
    private var popoverPresenter: MockPasswordPopoverPresenter!

    override func setUpWithError() throws {
        popoverPresenter = MockPasswordPopoverPresenter()

        #if NETWORK_PROTECTION
            let ipcClient = TunnelControllerIPCClient(machServiceName: "")
            let networkProtectionPopoverManager = NetworkProtectionNavBarPopoverManager(ipcClient: ipcClient)
            sut = NavigationBarPopovers(networkProtectionPopoverManager: NetworkProtectionNavBarPopoverManager(ipcClient: ipcClient), passwordPopoverPresenter: popoverPresenter)
        #else
            sut = NavigationBarPopovers(passwordPopoverPresenter: popoverPresenter)
        #endif

    }

    func testSetsPasswordPopoverDomainOnPopover() throws {
        // Given
        let domain = "test"

        // When
        sut.passwordManagementDomain = domain

        // Then
        XCTAssertEqual(popoverPresenter.passwordDomain, domain)
    }

    func testGetsPasswordPopoverDirtyState() throws {
        // When
        var dirtyResult = sut.isPasswordManagementDirty

        // Then
        XCTAssertFalse(dirtyResult)

        // Given
        popoverPresenter.isDirty = true

        // When
        dirtyResult = sut.isPasswordManagementDirty

        // Then
        XCTAssertTrue(dirtyResult)
    }

    func testGetsPasswordPopoverDisplayedState() throws {
        // When
        var displayedResult = sut.isPasswordManagementPopoverShown

        // Then
        XCTAssertFalse(displayedResult)

        // Given
        popoverPresenter.isDisplayed = true

        // When
        displayedResult = sut.isPasswordManagementPopoverShown

        // Then
        XCTAssertTrue(displayedResult)
    }
}
