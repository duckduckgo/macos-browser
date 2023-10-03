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

@MainActor
final class MoreOptionsMenuTests: XCTestCase {

    var tabCollectionViewModel: TabCollectionViewModel!
    var passwordManagerCoordinator: PasswordManagerCoordinator!
    var capturingActionDelegate: CapturingOptionsButtonMenuDelegate!
    var moreOptionMenu: MoreOptionsMenu!
    var internalUserDecider: InternalUserDeciderMock!

#if NETWORK_PROTECTION
    var networkProtectionVisibilityMock: NetworkProtectionVisibilityMock!
#endif

    override func setUp() {
        super.setUp()
        tabCollectionViewModel = TabCollectionViewModel()
        passwordManagerCoordinator = PasswordManagerCoordinator()
        capturingActionDelegate = CapturingOptionsButtonMenuDelegate()
        internalUserDecider = InternalUserDeciderMock()

#if NETWORK_PROTECTION
        networkProtectionVisibilityMock = NetworkProtectionVisibilityMock(visible: false)

        moreOptionMenu = MoreOptionsMenu(tabCollectionViewModel: tabCollectionViewModel,
                                         passwordManagerCoordinator: passwordManagerCoordinator,
                                         networkProtectionFeatureVisibility: networkProtectionVisibilityMock,
                                         internalUserDecider: internalUserDecider)
#else
        moreOptionMenu = MoreOptionsMenu(tabCollectionViewModel: tabCollectionViewModel,
                                         passwordManagerCoordinator: passwordManagerCoordinator,
                                         internalUserDecider: internalUserDecider)
#endif

        moreOptionMenu.actionDelegate = capturingActionDelegate
    }

    override func tearDown() {
        tabCollectionViewModel = nil
        passwordManagerCoordinator = nil
        capturingActionDelegate = nil
        moreOptionMenu = nil
        super.tearDown()
    }

    func testThatMoreOptionMenuHasTheExpectedItems_WhenNetworkProtectionIsEnabled() {
#if NETWORK_PROTECTION
        let moreOptionMenu = MoreOptionsMenu(tabCollectionViewModel: tabCollectionViewModel,
                                             passwordManagerCoordinator: passwordManagerCoordinator,
                                             networkProtectionFeatureVisibility: NetworkProtectionVisibilityMock(visible: true),
                                             internalUserDecider: internalUserDecider)
#else
        let moreOptionMenu = MoreOptionsMenu(tabCollectionViewModel: tabCollectionViewModel,
                                             passwordManagerCoordinator: passwordManagerCoordinator,
                                             internalUserDecider: internalUserDecider)
#endif

        XCTAssertEqual(moreOptionMenu.items[0].title, "Send Feedback")
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
        XCTAssertTrue(moreOptionMenu.items[13].title.hasPrefix(UserText.networkProtection))
        XCTAssertTrue(moreOptionMenu.items[14].isSeparatorItem)
        XCTAssertEqual(moreOptionMenu.items[15].title, UserText.settings)
#else
        XCTAssertTrue(moreOptionMenu.items[13].isSeparatorItem)
        XCTAssertEqual(moreOptionMenu.items[14].title, UserText.settings)
#endif
    }

    func testThatMoreOptionMenuHasTheExpectedItems_WhenNetworkProtectionIsDisabled() {
#if NETWORK_PROTECTION
        let moreOptionMenu = MoreOptionsMenu(tabCollectionViewModel: tabCollectionViewModel,
                                             passwordManagerCoordinator: passwordManagerCoordinator,
                                             networkProtectionFeatureVisibility: NetworkProtectionVisibilityMock(visible: false),
                                             internalUserDecider: internalUserDecider)
#else
        let moreOptionMenu = MoreOptionsMenu(tabCollectionViewModel: tabCollectionViewModel,
                                             passwordManagerCoordinator: passwordManagerCoordinator,
                                             internalUserDecider: internalUserDecider)
#endif

        XCTAssertEqual(moreOptionMenu.items[0].title, "Send Feedback")
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

    func isNetworkProtectionVisible() -> Bool {
        return visible
    }

    func disableForAllUsers() {
        // intentional no-op
    }

    func disableForWaitlistUsers() {
        // intentional no-op
    }
}
#endif
