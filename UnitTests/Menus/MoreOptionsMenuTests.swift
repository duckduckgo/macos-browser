//
//  MoreOptionsMenuTests.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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

import Combine
import NetworkProtection
import NetworkProtectionUI
import XCTest
import Subscription
import SubscriptionTestingUtilities

@testable import DuckDuckGo_Privacy_Browser

final class MoreOptionsMenuTests: XCTestCase {

    var tabCollectionViewModel: TabCollectionViewModel!
    var passwordManagerCoordinator: PasswordManagerCoordinator!
    var capturingActionDelegate: CapturingOptionsButtonMenuDelegate!
    var accountManager: AccountManagerMock!
    var moreOptionsMenu: MoreOptionsMenu!
    var internalUserDecider: InternalUserDeciderMock!

    var networkProtectionVisibilityMock: NetworkProtectionVisibilityMock!

    @MainActor
    override func setUp() {
        super.setUp()
        tabCollectionViewModel = TabCollectionViewModel()
        passwordManagerCoordinator = PasswordManagerCoordinator()
        capturingActionDelegate = CapturingOptionsButtonMenuDelegate()
        internalUserDecider = InternalUserDeciderMock()
        accountManager = AccountManagerMock()
        networkProtectionVisibilityMock = NetworkProtectionVisibilityMock(isInstalled: false, visible: false)
        moreOptionsMenu = MoreOptionsMenu(tabCollectionViewModel: tabCollectionViewModel,
                                   passwordManagerCoordinator: passwordManagerCoordinator,
                                   vpnFeatureGatekeeper: networkProtectionVisibilityMock,
                                   sharingMenu: NSMenu(),
                                   internalUserDecider: internalUserDecider,
                                   accountManager: accountManager)
        moreOptionsMenu.actionDelegate = capturingActionDelegate
    }

    @MainActor
    override func tearDown() {
        tabCollectionViewModel = nil
        passwordManagerCoordinator = nil
        capturingActionDelegate = nil
        moreOptionsMenu = nil
        accountManager = nil
        super.tearDown()
    }

    @MainActor
    func testThatMoreOptionMenuHasTheExpectedItemsAuthenticated() {
        moreOptionsMenu = MoreOptionsMenu(tabCollectionViewModel: tabCollectionViewModel,
                                         passwordManagerCoordinator: passwordManagerCoordinator,
                                         vpnFeatureGatekeeper: NetworkProtectionVisibilityMock(isInstalled: false, visible: true),
                                          subscriptionFeatureAvailability: SubscriptionFeatureAvailabilityMock(isFeatureAvailable: true, isSubscriptionPurchaseAllowed: true),
                                         sharingMenu: NSMenu(),
                                         internalUserDecider: internalUserDecider,
                                         accountManager: accountManager)

        XCTAssertEqual(moreOptionsMenu.items[0].title, UserText.sendFeedback)
        XCTAssertTrue(moreOptionsMenu.items[1].isSeparatorItem)
        XCTAssertEqual(moreOptionsMenu.items[2].title, UserText.plusButtonNewTabMenuItem)
        XCTAssertEqual(moreOptionsMenu.items[3].title, UserText.newWindowMenuItem)
        XCTAssertEqual(moreOptionsMenu.items[4].title, UserText.newBurnerWindowMenuItem)
        XCTAssertTrue(moreOptionsMenu.items[5].isSeparatorItem)
        XCTAssertEqual(moreOptionsMenu.items[6].title, UserText.zoom)
        XCTAssertTrue(moreOptionsMenu.items[7].isSeparatorItem)
        XCTAssertEqual(moreOptionsMenu.items[8].title, UserText.bookmarks)
        XCTAssertEqual(moreOptionsMenu.items[9].title, UserText.downloads)
        XCTAssertEqual(moreOptionsMenu.items[10].title, UserText.passwordManagementTitle)
        XCTAssertTrue(moreOptionsMenu.items[11].isSeparatorItem)
        XCTAssertEqual(moreOptionsMenu.items[12].title, UserText.emailOptionsMenuItem)

        XCTAssertTrue(moreOptionsMenu.items[13].isSeparatorItem)
        XCTAssertTrue(moreOptionsMenu.items[14].title.hasPrefix(UserText.subscriptionOptionsMenuItem))
        XCTAssertTrue(moreOptionsMenu.items[15].isSeparatorItem)
        XCTAssertEqual(moreOptionsMenu.items[16].title, UserText.settings)
    }

    @MainActor
    func testThatMoreOptionMenuHasTheExpectedItemsNotAuthenticated() {

        accountManager = AccountManagerMock()
        moreOptionsMenu = MoreOptionsMenu(tabCollectionViewModel: tabCollectionViewModel,
                                         passwordManagerCoordinator: passwordManagerCoordinator,
                                         vpnFeatureGatekeeper: NetworkProtectionVisibilityMock(isInstalled: false, visible: true),
                                         sharingMenu: NSMenu(),
                                         internalUserDecider: internalUserDecider,
                                         accountManager: accountManager)

        XCTAssertEqual(moreOptionsMenu.items[0].title, UserText.sendFeedback)
        XCTAssertTrue(moreOptionsMenu.items[1].isSeparatorItem)
        XCTAssertEqual(moreOptionsMenu.items[2].title, UserText.plusButtonNewTabMenuItem)
        XCTAssertEqual(moreOptionsMenu.items[3].title, UserText.newWindowMenuItem)
        XCTAssertEqual(moreOptionsMenu.items[4].title, UserText.newBurnerWindowMenuItem)
        XCTAssertTrue(moreOptionsMenu.items[5].isSeparatorItem)
        XCTAssertEqual(moreOptionsMenu.items[6].title, UserText.zoom)
        XCTAssertTrue(moreOptionsMenu.items[7].isSeparatorItem)
        XCTAssertEqual(moreOptionsMenu.items[8].title, UserText.bookmarks)
        XCTAssertEqual(moreOptionsMenu.items[9].title, UserText.downloads)
        XCTAssertEqual(moreOptionsMenu.items[10].title, UserText.passwordManagementTitle)
        XCTAssertTrue(moreOptionsMenu.items[11].isSeparatorItem)
        XCTAssertEqual(moreOptionsMenu.items[12].title, UserText.emailOptionsMenuItem)

        XCTAssertTrue(moreOptionsMenu.items[13].isSeparatorItem)
        XCTAssertTrue(moreOptionsMenu.items[14].title.hasPrefix(UserText.networkProtection))
        XCTAssertTrue(moreOptionsMenu.items[15].isSeparatorItem)
        XCTAssertEqual(moreOptionsMenu.items[16].title, UserText.settings)
    }

    // MARK: Zoom

    @MainActor
    func testWhenClickingDefaultZoomInZoomSubmenuThenTheActionDelegateIsAlerted() {
        guard let zoomSubmenu = moreOptionsMenu.zoomMenuItem.submenu else {
            XCTFail("No zoom submenu available")
            return
        }
        let defaultZoomItemIndex = zoomSubmenu.indexOfItem(withTitle: UserText.defaultZoomPageMoreOptionsItem)

        zoomSubmenu.performActionForItem(at: defaultZoomItemIndex)

        XCTAssertTrue(capturingActionDelegate.optionsButtonMenuRequestedAccessibilityPreferencesCalled)
    }

    // MARK: Preferences
    func testWhenClickingOnPreferenceMenuItemThenTheActionDelegateIsAlerted() {
        moreOptionsMenu.performActionForItem(at: moreOptionsMenu.items.count - 1)
        XCTAssertTrue(capturingActionDelegate.optionsButtonMenuRequestedPreferencesCalled)
    }

    // MARK: - Bookmarks

    func testWhenClickingOnBookmarkAllTabsMenuItemThenTheActionDelegateIsAlerted() throws {
        // GIVEN
        let bookmarksMenu = try XCTUnwrap(moreOptionsMenu.item(at: 8)?.submenu)
        let bookmarkAllTabsIndex = try XCTUnwrap(bookmarksMenu.indexOfItem(withTitle: UserText.bookmarkAllTabs))
        let bookmarkAllTabsMenuItem = try XCTUnwrap(bookmarksMenu.items[bookmarkAllTabsIndex])
        bookmarkAllTabsMenuItem.isEnabled = true

        // WHEN
        bookmarksMenu.performActionForItem(at: bookmarkAllTabsIndex)

        // THEN
        XCTAssertTrue(capturingActionDelegate.optionsButtonMenuRequestedBookmarkAllOpenTabsCalled)
    }

}

final class NetworkProtectionVisibilityMock: VPNFeatureGatekeeper {

    var onboardStatusPublisher: AnyPublisher<NetworkProtectionUI.OnboardingStatus, Never> {
        Just(.default).eraseToAnyPublisher()
    }

    var isInstalled: Bool
    var visible: Bool

    init(isInstalled: Bool, visible: Bool) {
        self.isInstalled = isInstalled
        self.visible = visible
    }

    func isVPNVisible() -> Bool {
        return visible
    }

    func shouldUninstallAutomatically() -> Bool {
        return !visible
    }

    func canStartVPN() async throws -> Bool {
        return false
    }

    func disableForAllUsers() async {
        // intentional no-op
    }

    var isEligibleForThankYouMessage: Bool {
        false
    }

    func disableIfUserHasNoAccess() async {
        // Intentional no-op
    }
}
