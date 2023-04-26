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
@testable import DuckDuckGo_Privacy_Browser

@MainActor
final class MoreOptionsMenuTests: XCTestCase {

    var tabCollectionViewModel: TabCollectionViewModel!
    var passwordManagerCoordinator: PasswordManagerCoordinator!
    var capturingActionDelegate: CapturingOptionsButtonMenuDelegate!
    var moreOptionMenu: MoreOptionsMenu!
    var internalUserDecider: InternalUserDeciderMock!

    override func setUp() {
        super.setUp()
        tabCollectionViewModel = TabCollectionViewModel()
        passwordManagerCoordinator = PasswordManagerCoordinator()
        capturingActionDelegate = CapturingOptionsButtonMenuDelegate()
        internalUserDecider = InternalUserDeciderMock()
        moreOptionMenu = MoreOptionsMenu(tabCollectionViewModel: tabCollectionViewModel, passwordManagerCoordinator: passwordManagerCoordinator, internalUserDecider: internalUserDecider)
        moreOptionMenu.actionDelegate = capturingActionDelegate
    }

    override func tearDown() {
        tabCollectionViewModel = nil
        passwordManagerCoordinator = nil
        capturingActionDelegate = nil
        moreOptionMenu = nil
        super.tearDown()
    }

    func testThatMoreOptionMenuHasTheExpectedItems() {
        XCTAssertEqual(moreOptionMenu.items.map { $0.isSeparatorItem ? "-" : $0.title },
                       [ UserText.sendFeedback,
                         "-",
                         UserText.plusButtonNewTabMenuItem,
                         UserText.newWindowMenuItem,
                         "-",
                         UserText.zoom,
                         "-",
                         UserText.bookmarks,
                         UserText.downloads,
                         UserText.passwordManagement,
                         "-",
                         UserText.emailOptionsMenuItem,
                         "-",
                         UserText.settings])
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
        moreOptionMenu.performActionForItem(at: 13)

        XCTAssertTrue(capturingActionDelegate.optionsButtonMenuRequestedPreferencesCalled)
    }

}
