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

import XCTest

#if NETWORK_PROTECTION
import NetworkProtection
#endif

@testable import DuckDuckGo_Privacy_Browser

final class MoreOptionsMenuTests: XCTestCase {

    var tabCollectionViewModel: TabCollectionViewModel!
    var passwordManagerCoordinator: PasswordManagerCoordinator!
    var capturingActionDelegate: CapturingOptionsButtonMenuDelegate!
    @MainActor
    lazy var moreOptionMenu: MoreOptionsMenu! = {
#if NETWORK_PROTECTION
        let menu = MoreOptionsMenu(tabCollectionViewModel: tabCollectionViewModel,
                                   passwordManagerCoordinator: passwordManagerCoordinator,
                                   networkProtectionFeatureVisibility: networkProtectionVisibilityMock,
                                   sharingMenu: NSMenu(),
                                   internalUserDecider: internalUserDecider)
#else
        let menu = MoreOptionsMenu(tabCollectionViewModel: tabCollectionViewModel,
                                   passwordManagerCoordinator: passwordManagerCoordinator,
                                   sharingMenu: NSMenu(),
                                   internalUserDecider: internalUserDecider)
#endif
        menu.actionDelegate = capturingActionDelegate
        return menu
    }()

    var internalUserDecider: InternalUserDeciderMock!

#if NETWORK_PROTECTION
    var networkProtectionVisibilityMock: NetworkProtectionVisibilityMock!
#endif

    @MainActor
    override func setUp() {
        super.setUp()
        tabCollectionViewModel = TabCollectionViewModel()
        passwordManagerCoordinator = PasswordManagerCoordinator()
        capturingActionDelegate = CapturingOptionsButtonMenuDelegate()
        internalUserDecider = InternalUserDeciderMock()

#if NETWORK_PROTECTION
        networkProtectionVisibilityMock = NetworkProtectionVisibilityMock(visible: false)
#endif
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
    func testThatMoreOptionMenuHasTheExpectedItems_WhenNetworkProtectionIsEnabled() {
#if NETWORK_PROTECTION
        moreOptionMenu = MoreOptionsMenu(tabCollectionViewModel: tabCollectionViewModel,
                                         passwordManagerCoordinator: passwordManagerCoordinator,
                                         networkProtectionFeatureVisibility: NetworkProtectionVisibilityMock(visible: true),
                                         sharingMenu: NSMenu(),
                                         internalUserDecider: internalUserDecider)
#else
        moreOptionMenu = MoreOptionsMenu(tabCollectionViewModel: tabCollectionViewModel,
                                         passwordManagerCoordinator: passwordManagerCoordinator,
                                         sharingMenu: NSMenu(),
                                         internalUserDecider: internalUserDecider)
#endif

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

#if NETWORK_PROTECTION
        XCTAssertTrue(moreOptionMenu.items[13].isSeparatorItem)
        XCTAssertTrue(moreOptionMenu.items[14].title.hasPrefix(UserText.networkProtection))
        XCTAssertTrue(moreOptionMenu.items[15].isSeparatorItem)
        XCTAssertEqual(moreOptionMenu.items[16].title, UserText.settings)
#else
        XCTAssertTrue(moreOptionMenu.items[13].isSeparatorItem)
        XCTAssertEqual(moreOptionMenu.items[14].title, UserText.settings)
#endif
    }

    @MainActor
    func testThatMoreOptionMenuHasTheExpectedItems_WhenNetworkProtectionIsDisabled() {
#if NETWORK_PROTECTION
        moreOptionMenu = MoreOptionsMenu(tabCollectionViewModel: tabCollectionViewModel,
                                         passwordManagerCoordinator: passwordManagerCoordinator,
                                         networkProtectionFeatureVisibility: NetworkProtectionVisibilityMock(visible: false),
                                         sharingMenu: NSMenu(),
                                         internalUserDecider: internalUserDecider)
#else
        moreOptionMenu = MoreOptionsMenu(tabCollectionViewModel: tabCollectionViewModel,
                                         passwordManagerCoordinator: passwordManagerCoordinator,
                                         sharingMenu: NSMenu(),
                                         internalUserDecider: internalUserDecider)
#endif

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
        XCTAssertTrue(moreOptionMenu.items[13].isSeparatorItem)
        XCTAssertEqual(moreOptionMenu.items[14].title, UserText.settings)
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
        moreOptionMenu.performActionForItem(at: 14)

        XCTAssertTrue(capturingActionDelegate.optionsButtonMenuRequestedPreferencesCalled)
    }

}

#if NETWORK_PROTECTION
final class NetworkProtectionVisibilityMock: NetworkProtectionFeatureVisibility {

    var visible: Bool

    init(visible: Bool) {
        self.visible = visible
    }

    func shouldUninstallAutomatically() -> Bool {
        return !visible
    }

    func isNetworkProtectionVisible() -> Bool {
        return visible
    }

    func isFeatureEnabled() async throws -> Bool {
        return false
    }

    func disableForAllUsers() async {
        // intentional no-op
    }

    func disableForWaitlistUsers() {
        // intentional no-op
    }

    var isEligibleForThankYouMessage: Bool {
        false
    }

    func disableIfUserHasNoAccess() async -> Bool {
        return false
    }
}
#endif
