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
import Subscription

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

    override func tearDown() {
        delegate.clear()
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
//        XCTAssertEqual(menu.item(at: 8)?.title, UserText.closeTabsToTheRight)
        XCTAssertEqual(menu.item(at: 8)?.title, UserText.moveTabToNewWindow)
    }

    func testThatMuteIsShownWhenCurrentAudioStateIsUnmuted() {
        delegate.audioState = .unmuted
        tabBarViewItem.menuNeedsUpdate(menu)

        XCTAssertTrue(menu.item(at: 5)?.isSeparatorItem ?? false)
        XCTAssertEqual(menu.item(at: 6)?.title, UserText.muteTab)
        XCTAssertTrue(menu.item(at: 7)?.isSeparatorItem ?? false)
    }

    func testThatUnmuteIsShownWhenCurrentAudioStateIsMuted() {
        delegate.audioState = .muted
        tabBarViewItem.menuNeedsUpdate(menu)

        XCTAssertTrue(menu.item(at: 5)?.isSeparatorItem ?? false)
        XCTAssertEqual(menu.item(at: 6)?.title, UserText.unmuteTab)
        XCTAssertTrue(menu.item(at: 7)?.isSeparatorItem ?? false)
    }

    func testWhenOneTabCloseThenOtherTabsItemIsDisabled() {
        tabBarViewItem.menuNeedsUpdate(menu)

        let submenu = menu.items .first { $0.title == UserText.closeOtherTabs }
        let item = submenu?.submenu?.items .first { $0.title == UserText.closeAllOtherTabs }
        XCTAssertFalse(item?.isEnabled ?? true)
    }

    func testWhenMultipleTabsThenCloseOtherTabsItemIsEnabled() {
        delegate.hasItemsToTheRight = true
        tabBarViewItem.menuNeedsUpdate(menu)

        let submenu = menu.items .first { $0.title == UserText.closeOtherTabs }
        let item = submenu?.submenu?.items .first { $0.title == UserText.closeAllOtherTabs }
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

    func testWhenNoTabsToTheLeftThenCloseTabsToTheLeftIsDisabled() {
        tabBarViewItem.menuNeedsUpdate(menu)

        let submenu = menu.items .first { $0.title == UserText.closeOtherTabs }
        let item = submenu?.submenu?.items .first { $0.title == UserText.closeTabsToTheLeft }
        XCTAssertFalse(item?.isEnabled ?? true)
    }

    func testWhenTabsToTheLeftThenCloseTabsToTheLeftIsEnabled() {
        delegate.hasItemsToTheLeft = true
        tabBarViewItem.menuNeedsUpdate(menu)

        let submenu = menu.items .first { $0.title == UserText.closeOtherTabs }
        let item = submenu?.submenu?.items .first { $0.title == UserText.closeTabsToTheLeft }
        XCTAssertTrue(item?.isEnabled ?? false)
    }

    func testWhenNoTabsToTheRightThenCloseTabsToTheRightIsDisabled() {
        tabBarViewItem.menuNeedsUpdate(menu)

        let submenu = menu.items .first { $0.title == UserText.closeOtherTabs }
        let item = submenu?.submenu?.items .first { $0.title == UserText.closeTabsToTheRight }
        XCTAssertFalse(item?.isEnabled ?? true)
    }

    func testWhenTabsToTheRightThenCloseTabsToTheRightIsEnabled() {
        delegate.hasItemsToTheRight = true
        tabBarViewItem.menuNeedsUpdate(menu)

        let submenu = menu.items .first { $0.title == UserText.closeOtherTabs }
        let item = submenu?.submenu?.items .first { $0.title == UserText.closeTabsToTheRight }
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
        tabBarViewItem.titleTextField = textField
        tabBarViewItem.faviconImageView = imageView
        tabBarViewItem.faviconWrapperView = imageView
        tabBarViewItem.titleTextFieldLeadingConstraint = constraints
        tabBarViewItem.permissionButton = button
        tabBarViewItem.tabLoadingPermissionLeadingConstraint = constraints
        tabBarViewItem.closeButton = mouseButton

        // Update url
        let tab = Tab()
        tab.url = URL(string: "https://www.apple.com")!
        delegate.mockedCurrentTab = tab
        let vm = TabViewModel(tab: tab)
        tabBarViewItem.subscribe(to: vm, tabCollectionViewModel: TabCollectionViewModel())
        // update menu
        tabBarViewItem.menuNeedsUpdate(menu)
        let item = menu.items .first { $0.title == UserText.fireproofSite }
        XCTAssertTrue(item?.isEnabled ?? false)

        let duplicateItem = menu.items.first { $0.title == UserText.duplicateTab }
        XCTAssertTrue(duplicateItem?.isEnabled ?? false)

        let pinItem = menu.items.first { $0.title == UserText.pinTab }
        XCTAssertTrue(pinItem?.isEnabled ?? false)

        let bookmarkItem = menu.items.first { $0.title == UserText.bookmarkThisPage }
        XCTAssertTrue(bookmarkItem?.isEnabled ?? false)
    }

    func testSubscriptionTabDisabledItems() {
        // Set up fake views for the TabBarViewItems
        let textField = NSTextField()
        let imageView = NSImageView()
        let constraints = NSLayoutConstraint()
        let button = NSButton()
        let mouseButton = MouseOverButton()
        tabBarViewItem.titleTextField = textField
        tabBarViewItem.faviconImageView = imageView
        tabBarViewItem.faviconWrapperView = imageView
        tabBarViewItem.titleTextFieldLeadingConstraint = constraints
        tabBarViewItem.permissionButton = button
        tabBarViewItem.tabLoadingPermissionLeadingConstraint = constraints
        tabBarViewItem.closeButton = mouseButton

        // Update url
        let tab = Tab(content: .subscription(.subscriptionPurchase))
        delegate.mockedCurrentTab = tab
        let vm = TabViewModel(tab: tab)
        tabBarViewItem.subscribe(to: vm, tabCollectionViewModel: TabCollectionViewModel())
        // update menu
        tabBarViewItem.menuNeedsUpdate(menu)

        let duplicateItem = menu.items.first { $0.title == UserText.duplicateTab }
        XCTAssertFalse(duplicateItem?.isEnabled ?? true)

        let pinItem = menu.items.first { $0.title == UserText.pinTab }
        XCTAssertFalse(pinItem?.isEnabled ?? true)

        let bookmarkItem = menu.items.first { $0.title == UserText.bookmarkThisPage }
        XCTAssertFalse(bookmarkItem?.isEnabled ?? true)
    }

}
