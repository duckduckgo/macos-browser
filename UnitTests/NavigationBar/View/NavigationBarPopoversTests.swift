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

private final class MockNSPopoverDelegate: NSObject, NSPopoverDelegate {}

final class NavigationBarPopoversTests: XCTestCase {

    private var sut: NavigationBarPopovers!
    private var autofillPopoverPresenter: MockAutofillPopoverPresenter!

    @MainActor
    override func setUpWithError() throws {
        autofillPopoverPresenter = MockAutofillPopoverPresenter()
        sut = NavigationBarPopovers(networkProtectionPopoverManager: NetPPopoverManagerMock(), autofillPopoverPresenter: autofillPopoverPresenter, isBurner: false)
    }

    func testSetsPasswordPopoverDomainOnPopover() throws {
        // Given
        let domain = "test"

        // When
        sut.passwordManagementDomain = domain

        // Then
        XCTAssertEqual(autofillPopoverPresenter.passwordDomain, domain)
    }

    func testGetsPasswordPopoverDirtyState() throws {
        // When
        var dirtyResult = sut.isPasswordManagementDirty

        // Then
        XCTAssertFalse(dirtyResult)

        // Given
        autofillPopoverPresenter.isDirty = true

        // When
        dirtyResult = sut.isPasswordManagementDirty

        // Then
        XCTAssertTrue(dirtyResult)
    }

    func testGetsPasswordPopoverShownState() throws {
        // When
        var displayedResult = sut.isPasswordManagementPopoverShown

        // Then
        XCTAssertFalse(displayedResult)

        // Given
        autofillPopoverPresenter.isShown = true

        // When
        displayedResult = sut.isPasswordManagementPopoverShown

        // Then
        XCTAssertTrue(displayedResult)
    }

    func testShowsPasswordPopoverWithCategory() throws {
        // When
        sut.showPasswordManagementPopover(selectedCategory: nil, from: MouseOverButton(), withDelegate: MockNSPopoverDelegate(), source: nil)

        // Then
        XCTAssertTrue(autofillPopoverPresenter.didShowWithCategory)
    }

    func testShowsPasswordPopoverWithSelectedWebsite() throws {
        // Given
        let account = SecureVaultModels.WebsiteAccount(id: "")

        // When
        sut.showPasswordManagerPopover(selectedWebsiteAccount: account, from: MouseOverButton(), withDelegate: MockNSPopoverDelegate())

        // Then
        XCTAssertTrue(autofillPopoverPresenter.didShowWithSelectedAccount)
    }

}
