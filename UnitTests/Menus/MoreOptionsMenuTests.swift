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

@testable import DuckDuckGo_Privacy_Browser

final class MoreOptionsMenuTests: XCTestCase {

    var tabCollectionViewModel: TabCollectionViewModel!
    var passwordManagerCoordinator: PasswordManagerCoordinator!
    var capturingActionDelegate: CapturingOptionsButtonMenuDelegate!
    @MainActor
    lazy var moreOptionMenu: MoreOptionsMenu! = {
        let menu = MoreOptionsMenu(tabCollectionViewModel: tabCollectionViewModel,
                                   passwordManagerCoordinator: passwordManagerCoordinator,
                                   networkProtectionFeatureVisibility: networkProtectionVisibilityMock,
                                   sharingMenu: NSMenu(),
                                   internalUserDecider: internalUserDecider)
        menu.actionDelegate = capturingActionDelegate
        return menu
    }()

    var internalUserDecider: InternalUserDeciderMock!

    var networkProtectionVisibilityMock: NetworkProtectionVisibilityMock!

    @MainActor
    override func setUp() {
        super.setUp()
        tabCollectionViewModel = TabCollectionViewModel()
        passwordManagerCoordinator = PasswordManagerCoordinator()
        capturingActionDelegate = CapturingOptionsButtonMenuDelegate()
        internalUserDecider = InternalUserDeciderMock()

        networkProtectionVisibilityMock = NetworkProtectionVisibilityMock(isInstalled: false, visible: false)
    }

    @MainActor
    override func tearDown() {
        tabCollectionViewModel = nil
        passwordManagerCoordinator = nil
        capturingActionDelegate = nil
        moreOptionMenu = nil
        super.tearDown()
    }

    @MainActor
    func testThatMoreOptionMenuHasTheExpectedItems() {
        moreOptionMenu = MoreOptionsMenu(tabCollectionViewModel: tabCollectionViewModel,
                                         passwordManagerCoordinator: passwordManagerCoordinator,
                                         networkProtectionFeatureVisibility: NetworkProtectionVisibilityMock(isInstalled: false, visible: true),
                                         sharingMenu: NSMenu(),
                                         internalUserDecider: internalUserDecider)

        XCTAssertEqual(moreOptionMenu.items[0].title, UserText.sendFeedback)
        XCTAssertTrue(moreOptionMenu.items[1].isSeparatorItem)
        XCTAssertEqual(moreOptionMenu.items[2].title, UserText.plusButtonNewTabMenuItem)
        XCTAssertEqual(moreOptionMenu.items[3].title, UserText.newWindowMenuItem)
        XCTAssertEqual(moreOptionMenu.items[4].title, UserText.newBurnerWindowMenuItem)
        XCTAssertTrue(moreOptionMenu.items[5].isSeparatorItem)
        XCTAssertEqual(moreOptionMenu.items[6].title, UserText.zoom)
        XCTAssertTrue(moreOptionMenu.items[7].isSeparatorItem)
        XCTAssertEqual(moreOptionMenu.items[8].title, UserText.bookmarks)
        XCTAssertEqual(moreOptionMenu.items[9].title, UserText.downloads)
        XCTAssertEqual(moreOptionMenu.items[10].title, UserText.passwordManagement)
        XCTAssertTrue(moreOptionMenu.items[11].isSeparatorItem)
        XCTAssertEqual(moreOptionMenu.items[12].title, UserText.emailOptionsMenuItem)

        if AccountManager(subscriptionAppGroup: Bundle.main.appGroup(bundle: .subs)).isUserAuthenticated {
            XCTAssertTrue(moreOptionMenu.items[13].isSeparatorItem)
            XCTAssertTrue(moreOptionMenu.items[14].title.hasPrefix(UserText.networkProtection))
            XCTAssertTrue(moreOptionMenu.items[15].title.hasPrefix(UserText.identityTheftRestorationOptionsMenuItem))
            XCTAssertTrue(moreOptionMenu.items[16].isSeparatorItem)
            XCTAssertEqual(moreOptionMenu.items[17].title, UserText.settings)
        } else {
            XCTAssertTrue(moreOptionMenu.items[13].isSeparatorItem)
            XCTAssertTrue(moreOptionMenu.items[14].title.hasPrefix(UserText.networkProtection))
            XCTAssertTrue(moreOptionMenu.items[15].isSeparatorItem)
            XCTAssertEqual(moreOptionMenu.items[16].title, UserText.settings)
        }
    }

    // MARK: Zoom

    @MainActor
    func testWhenClickingDefaultZoomInZoomSubmenuThenTheActionDelegateIsAlerted() {
        guard let zoomSubmenu = moreOptionMenu.zoomMenuItem.submenu else {
            XCTFail("No zoom submenu available")
            return
        }
        let defaultZoomItemIndex = zoomSubmenu.indexOfItem(withTitle: UserText.defaultZoomPageMoreOptionsItem)

        zoomSubmenu.performActionForItem(at: defaultZoomItemIndex)

        XCTAssertTrue(capturingActionDelegate.optionsButtonMenuRequestedAppearancePreferencesCalled)
    }

    // MARK: Preferences

    @MainActor
    func testWhenClickingOnPreferenceMenuItemThenTheActionDelegateIsAlerted() {
        moreOptionMenu.performActionForItem(at: moreOptionMenu.items.count - 1)
        XCTAssertTrue(capturingActionDelegate.optionsButtonMenuRequestedPreferencesCalled)
    }

    // MARK: - Bookmarks

    @MainActor
    func testWhenClickingOnBookmarkAllTabsMenuItemThenTheActionDelegateIsAlerted() throws {
        // GIVEN
        let bookmarksMenu = try XCTUnwrap(moreOptionMenu.item(at: 8)?.submenu)
        let bookmarkAllTabsIndex = try XCTUnwrap(bookmarksMenu.indexOfItem(withTitle: UserText.bookmarkAllTabs))
        let bookmarkAllTabsMenuItem = try XCTUnwrap(bookmarksMenu.items[bookmarkAllTabsIndex])
        bookmarkAllTabsMenuItem.isEnabled = true

        // WHEN
        bookmarksMenu.performActionForItem(at: bookmarkAllTabsIndex)

        // THEN
        XCTAssertTrue(capturingActionDelegate.optionsButtonMenuRequestedBookmarkAllOpenTabsCalled)
    }

}

final class NetworkProtectionVisibilityMock: NetworkProtectionFeatureVisibility {

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

    func disableIfUserHasNoAccess() async throws {
        // Intentional no-op
    }
}
