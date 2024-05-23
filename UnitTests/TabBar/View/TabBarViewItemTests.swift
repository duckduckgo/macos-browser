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
@testable import Subscription
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
        XCTAssertEqual(menu.item(at: 3)?.title, UserText.fireproofSite)
        XCTAssertTrue(menu.item(at: 5)?.isSeparatorItem ?? false)
        XCTAssertEqual(menu.item(at: 6)?.title, UserText.bookmarkAllTabs)
        XCTAssertTrue(menu.item(at: 7)?.isSeparatorItem ?? false)
        XCTAssertEqual(menu.item(at: 8)?.title, UserText.closeTab)
        XCTAssertEqual(menu.item(at: 9)?.title, UserText.closeOtherTabs)
        XCTAssertEqual(menu.item(at: 10)?.title, UserText.moveTabToNewWindow)

        // Check "Close Other Tabs" submenu
        guard let submenu = menu.item(at: 9)?.submenu else {
            XCTFail("\"Close Other Tabs\" menu item should have a submenu")
            return
        }
        XCTAssertEqual(submenu.item(at: 0)?.title, UserText.closeTabsToTheLeft)
        XCTAssertEqual(submenu.item(at: 1)?.title, UserText.closeTabsToTheRight)
        XCTAssertEqual(submenu.item(at: 2)?.title, UserText.closeAllOtherTabs)
    }

    func testThatMuteIsShownWhenCurrentAudioStateIsUnmuted() {
        delegate.audioState = .unmuted
        tabBarViewItem.menuNeedsUpdate(menu)

        XCTAssertFalse(menu.item(at: 1)?.isSeparatorItem ?? true)
        XCTAssertEqual(menu.item(at: 2)?.title, UserText.muteTab)
        XCTAssertTrue(menu.item(at: 3)?.isSeparatorItem ?? false)
    }

    func testThatUnmuteIsShownWhenCurrentAudioStateIsMuted() {
        delegate.audioState = .muted
        tabBarViewItem.menuNeedsUpdate(menu)

        XCTAssertFalse(menu.item(at: 1)?.isSeparatorItem ?? true)
        XCTAssertEqual(menu.item(at: 2)?.title, UserText.unmuteTab)
        XCTAssertTrue(menu.item(at: 3)?.isSeparatorItem ?? false)
    }

    func testWhenURLIsNotBookmarkedThenBookmarkThisPageIsShown() {
        // GIVEN
        delegate.isTabBarItemAlreadyBookmarked = false

        // WHEN
        tabBarViewItem.menuNeedsUpdate(menu)

        // THEN
        XCTAssertEqual(menu.item(at: 4)?.title, UserText.bookmarkThisPage)
    }

    func testWhenURLIsBookmarkedThenDeleteBookmarkIsShown() {
        // GIVEN
        delegate.isTabBarItemAlreadyBookmarked = true

        // WHEN
        tabBarViewItem.menuNeedsUpdate(menu)

        // THEN
        XCTAssertEqual(menu.item(at: 4)?.title, UserText.deleteBookmark)
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
        let url = SubscriptionURL.purchase.subscriptionURL(environment: .production)
        let tab = Tab(content: .subscription(url))
        delegate.mockedCurrentTab = tab
        let vm = TabViewModel(tab: tab)
        tabBarViewItem.subscribe(to: vm, tabCollectionViewModel: TabCollectionViewModel())
        // update menu
        tabBarViewItem.menuNeedsUpdate(menu)

        let duplicateItem = menu.items.first { $0.title == UserText.duplicateTab }
        XCTAssertFalse(duplicateItem?.isEnabled ?? true)

        let pinItem = menu.items.first { $0.title == UserText.pinTab }
        XCTAssertFalse(pinItem?.isEnabled ?? true)
    }

    func testWhenCanBookmarkAllOpenTabsThenBookmarkAllOpenTabsItemIsEnabled() throws {
        // GIVEN
        delegate.canBookmarkAllOpenTabs = true
        tabBarViewItem.menuNeedsUpdate(menu)

        // WHEN
        let item = try XCTUnwrap(menu.item(withTitle: UserText.bookmarkAllTabs))

        // THEN
        XCTAssertTrue(item.isEnabled)
    }

    func testWhenCannotBookmarkAllOpenTabsThenBookmarkAllOpenTabsItemIsDisabled() throws {
        // GIVEN
        delegate.canBookmarkAllOpenTabs = false
        tabBarViewItem.menuNeedsUpdate(menu)

        // WHEN
        let item = try XCTUnwrap(menu.item(withTitle: UserText.bookmarkAllTabs))

        // THEN
        XCTAssertFalse(item.isEnabled)
    }

    func testWhenClickingOnBookmarkAllTabsThenTheActionDelegateIsNotified() throws {
        // GIVEN
        delegate.canBookmarkAllOpenTabs = true
        tabBarViewItem.menuNeedsUpdate(menu)
        let index = try XCTUnwrap(menu.indexOfItem(withTitle: UserText.bookmarkAllTabs))
        XCTAssertFalse(delegate.tabBarViewItemBookmarkAllOpenTabsActionCalled)

        // WHEN
        menu.performActionForItem(at: index)

        // THEN
        XCTAssertTrue(delegate.tabBarViewItemBookmarkAllOpenTabsActionCalled)
    }

    func testWhenClickingOnBookmarkThisPageThenTheActionDelegateIsNotified() throws {
        // GIVEN
        delegate.isTabBarItemAlreadyBookmarked = false
        tabBarViewItem.menuNeedsUpdate(menu)
        let index = try XCTUnwrap(menu.indexOfItem(withTitle: UserText.bookmarkThisPage))
        XCTAssertFalse(delegate.tabBarViewItemBookmarkThisPageActionCalled)

        // WHEN
        menu.performActionForItem(at: index)

        // THEN
        XCTAssertTrue(delegate.tabBarViewItemBookmarkThisPageActionCalled)
    }

    func testWhenClickingOnDeleteBookmarkThenTheActionDelegateIsNotified() throws {
        // GIVEN
        delegate.isTabBarItemAlreadyBookmarked = true
        tabBarViewItem.menuNeedsUpdate(menu)
        let index = try XCTUnwrap(menu.indexOfItem(withTitle: UserText.deleteBookmark))
        XCTAssertFalse(delegate.tabBarViewItemRemoveBookmarkActionCalled)

        // WHEN
        menu.performActionForItem(at: index)

        // THEN
        XCTAssertTrue(delegate.tabBarViewItemRemoveBookmarkActionCalled)
    }

}
