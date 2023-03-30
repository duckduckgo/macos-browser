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

final class MoreOptionsMenuTests: XCTestCase {

    var tabCollectionViewModel: TabCollectionViewModel!
    var passwordManagerCoordinator: PasswordManagerCoordinator!
    var capturingActionDelegate: CapturingOptionsButtonMenuDelegate!
    var moreOptionMenu: MoreOptionsMenu!

    override func setUp() {
        super.setUp()
        tabCollectionViewModel = TabCollectionViewModel()
        passwordManagerCoordinator = PasswordManagerCoordinator()
        capturingActionDelegate = CapturingOptionsButtonMenuDelegate()
        moreOptionMenu = MoreOptionsMenu(tabCollectionViewModel: tabCollectionViewModel, passwordManagerCoordinator: passwordManagerCoordinator)
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
        XCTAssertEqual(moreOptionMenu.items[0].title, "Send Feedback")
        XCTAssertTrue(moreOptionMenu.items[1].isSeparatorItem)
        XCTAssertEqual(moreOptionMenu.items[2].title, UserText.plusButtonNewTabMenuItem)
        XCTAssertEqual(moreOptionMenu.items[3].title, UserText.newWindowMenuItem)
        XCTAssertTrue(moreOptionMenu.items[4].isSeparatorItem)
        XCTAssertEqual(moreOptionMenu.items[5].title, UserText.zoom)
        XCTAssertTrue(moreOptionMenu.items[6].isSeparatorItem)
        XCTAssertEqual(moreOptionMenu.items[7].title, UserText.bookmarks)
        XCTAssertEqual(moreOptionMenu.items[8].title, UserText.downloads)
        XCTAssertEqual(moreOptionMenu.items[9].title, UserText.passwordManagement)
        XCTAssertTrue(moreOptionMenu.items[10].isSeparatorItem)
        XCTAssertEqual(moreOptionMenu.items[11].title, UserText.emailOptionsMenuItem)
        XCTAssertTrue(moreOptionMenu.items[12].isSeparatorItem)
        XCTAssertEqual(moreOptionMenu.items[13].title, UserText.settings)
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
