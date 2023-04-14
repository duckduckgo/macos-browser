//
//  TabBarViewItemTests.swift
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
final class TabBarViewItemTests: XCTestCase {

    var delegate: MockTabViewItemDelegate!
    var menu: NSMenu!
    var tabBarViewItem: TabBarViewItem!

    override func setUp() {
        delegate = MockTabViewItemDelegate()
        menu = NSMenu()
        tabBarViewItem = TabBarViewItem()
        tabBarViewItem.delegate = delegate
    }

    func testThatAllExpectedItemsAreShown() {
        tabBarViewItem.menuNeedsUpdate(menu)

        XCTAssertEqual(menu.item(at: 0)?.title, UserText.duplicateTab)
        XCTAssertEqual(menu.item(at: 1)?.title, UserText.pinTab)
        XCTAssertTrue(menu.item(at: 2)?.isSeparatorItem ?? false)
        XCTAssertEqual(menu.item(at: 3)?.title, UserText.bookmarkThisPage)
        XCTAssertEqual(menu.item(at: 4)?.title, UserText.fireproofSite)
        XCTAssertTrue(menu.item(at: 5)?.isSeparatorItem ?? false)
        XCTAssertEqual(menu.item(at: 6)?.title, UserText.closeTab)
        XCTAssertEqual(menu.item(at: 7)?.title, UserText.closeOtherTabs)
        XCTAssertEqual(menu.item(at: 8)?.title, UserText.closeTabsToTheRight)
        XCTAssertEqual(menu.item(at: 9)?.title, UserText.moveTabToNewWindow)
    }

    func testWhenOneTabCloseThenOtherTabsItemIsDisabled() {
        tabBarViewItem.menuNeedsUpdate(menu)

        let item = menu.items .first { $0.title == UserText.closeOtherTabs }
        XCTAssertFalse(item?.isEnabled ?? true)
    }

    func testWhenMultipleTabsThenCloseOtherTabsItemIsEnabled() {
        delegate.hasItemsToTheRight = true
        tabBarViewItem.menuNeedsUpdate(menu)

        let item = menu.items .first { $0.title == UserText.closeOtherTabs }
        XCTAssertTrue(item?.isEnabled ?? false)
    }

    func testWhenOneTabThenMoveTabToNewWindowIsDisabled() {
        tabBarViewItem.menuNeedsUpdate(menu)

        let item = menu.items .first { $0.title == UserText.moveTabToNewWindow }
        XCTAssertFalse(item?.isEnabled ?? true)
    }

    func testWhenMultipleTabsThenMoveTabToNewWindowIsEnabled() {
        delegate.hasItemsToTheRight = true
        tabBarViewItem.menuNeedsUpdate(menu)

        let item = menu.items .first { $0.title == UserText.moveTabToNewWindow }
        XCTAssertTrue(item?.isEnabled ?? false)
    }

    func testWhenNoTabsToTheRightThenCloseTabsToTheRightIsDisabled() {
        tabBarViewItem.menuNeedsUpdate(menu)

        let item = menu.items .first { $0.title == UserText.closeTabsToTheRight }
        XCTAssertFalse(item?.isEnabled ?? true)
    }

    func testWhenTabsToTheRightThenCloseTabsToTheRightIsEnabled() {
        delegate.hasItemsToTheRight = true
        tabBarViewItem.menuNeedsUpdate(menu)

        let item = menu.items .first { $0.title == UserText.closeTabsToTheRight }
        XCTAssertTrue(item?.isEnabled ?? false)
    }

    func testWhenNoUrlThenFireProofSiteItemIsDisabled() {
        tabBarViewItem.menuNeedsUpdate(menu)

        let item = menu.items .first { $0.title == UserText.fireproofSite }
        XCTAssertFalse(item?.isEnabled ?? true)
    }

    func testWhenFireproofableThenUrlFireProofSiteItemIsDisabled() {
        // Set up fake views for the TabBarViewItems
        let textField = NSTextField()
        let imageView = NSImageView()
        let constraints = NSLayoutConstraint()
        let button = NSButton()
        let mouseButton = MouseOverButton()
        let windowDraggingView = WindowDraggingView()
        tabBarViewItem.titleTextField = textField
        tabBarViewItem.faviconImageView = imageView
        tabBarViewItem.faviconWrapperView = imageView
        tabBarViewItem.titleTextFieldLeadingConstraint = constraints
        tabBarViewItem.permissionButton = button
        tabBarViewItem.tabLoadingPermissionLeadingConstraint = constraints
        tabBarViewItem.closeButton = mouseButton
        tabBarViewItem.windowDraggingView = windowDraggingView

        // Update url
        let tab = Tab()
        tab.url = URL(string: "https://www.apple.com")
        let vm = TabViewModel(tab: tab)
        tabBarViewItem.subscribe(to: vm, tabCollectionViewModel: TabCollectionViewModel())
        // update menu
        tabBarViewItem.menuNeedsUpdate(menu)
        let item = menu.items .first { $0.title == UserText.fireproofSite }
        XCTAssertTrue(item?.isEnabled ?? false)
    }
}
