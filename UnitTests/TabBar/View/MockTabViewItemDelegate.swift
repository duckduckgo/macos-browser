//
//  MockTabViewItemDelegate.swift
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

import Foundation
@testable import DuckDuckGo_Privacy_Browser

class MockTabViewItemDelegate: TabBarViewItemDelegate {

    var mockedCurrentTab: Tab?

    var canBookmarkAllOpenTabs = false
    var hasItemsToTheLeft = false
    var hasItemsToTheRight = false
    var audioState: WKWebView.AudioState?
    var isTabBarItemAlreadyBookmarked = false

    private(set) var tabBarViewItemBookmarkThisPageActionCalled = false
    private(set) var tabBarViewItemRemoveBookmarkActionCalled = false
    private(set) var tabBarViewItemBookmarkAllOpenTabsActionCalled = false

    func tabBarViewItem(_ tabBarViewItem: DuckDuckGo_Privacy_Browser.TabBarViewItem, isMouseOver: Bool) {

    }

    func tabBarViewItemCloseAction(_ tabBarViewItem: DuckDuckGo_Privacy_Browser.TabBarViewItem) {

    }

    func tabBarViewItemTogglePermissionAction(_ tabBarViewItem: DuckDuckGo_Privacy_Browser.TabBarViewItem) {

    }

    func tabBarViewItemCloseOtherAction(_ tabBarViewItem: DuckDuckGo_Privacy_Browser.TabBarViewItem) {

    }

    func tabBarViewItemCloseToTheLeftAction(_ tabBarViewItem: DuckDuckGo_Privacy_Browser.TabBarViewItem) {

    }

    func tabBarViewItemCloseToTheRightAction(_ tabBarViewItem: DuckDuckGo_Privacy_Browser.TabBarViewItem) {

    }

    func tabBarViewItemCanBeDuplicated(_ tabBarViewItem: DuckDuckGo_Privacy_Browser.TabBarViewItem) -> Bool {
        mockedCurrentTab?.content.canBeDuplicated ?? true
    }

    func tabBarViewItemDuplicateAction(_ tabBarViewItem: DuckDuckGo_Privacy_Browser.TabBarViewItem) {

    }

    func tabBarViewItemCanBePinned(_ tabBarViewItem: DuckDuckGo_Privacy_Browser.TabBarViewItem) -> Bool {
        mockedCurrentTab?.content.canBePinned ?? true
    }

    func tabBarViewItemPinAction(_ tabBarViewItem: DuckDuckGo_Privacy_Browser.TabBarViewItem) {

    }

    func tabBarViewItemCanBeBookmarked(_ tabBarViewItem: DuckDuckGo_Privacy_Browser.TabBarViewItem) -> Bool {
        mockedCurrentTab?.content.canBeBookmarked ?? true
    }

    func tabBarViewItemIsAlreadyBookmarked(_ tabBarViewItem: TabBarViewItem) -> Bool {
        isTabBarItemAlreadyBookmarked
    }

    func tabBarViewItemBookmarkThisPageAction(_ tabBarViewItem: DuckDuckGo_Privacy_Browser.TabBarViewItem) {
        tabBarViewItemBookmarkThisPageActionCalled = true
    }

    func tabBarViewItemRemoveBookmarkAction(_ tabBarViewItem: TabBarViewItem) {
        tabBarViewItemRemoveBookmarkActionCalled = true
    }

    func tabBarViewAllItemsCanBeBookmarked(_ tabBarViewItem: DuckDuckGo_Privacy_Browser.TabBarViewItem) -> Bool {
        canBookmarkAllOpenTabs
    }

    func tabBarViewItemBookmarkAllOpenTabsAction(_ tabBarViewItem: DuckDuckGo_Privacy_Browser.TabBarViewItem) {
        tabBarViewItemBookmarkAllOpenTabsActionCalled = true
    }

    func tabBarViewItemMoveToNewWindowAction(_ tabBarViewItem: DuckDuckGo_Privacy_Browser.TabBarViewItem) {

    }

    func tabBarViewItemMoveToNewBurnerWindowAction(_ tabBarViewItem: DuckDuckGo_Privacy_Browser.TabBarViewItem) {

    }

    func tabBarViewItemFireproofSite(_ tabBarViewItem: DuckDuckGo_Privacy_Browser.TabBarViewItem) {

    }

    func tabBarViewItemRemoveFireproofing(_ tabBarViewItem: DuckDuckGo_Privacy_Browser.TabBarViewItem) {

    }

    func tabBarViewItemMuteUnmuteSite(_ tabBarViewItem: TabBarViewItem) {

    }

    func otherTabBarViewItemsState(for tabBarViewItem: DuckDuckGo_Privacy_Browser.TabBarViewItem) -> DuckDuckGo_Privacy_Browser.OtherTabBarViewItemsState {
        OtherTabBarViewItemsState(hasItemsToTheLeft: hasItemsToTheLeft, hasItemsToTheRight: hasItemsToTheRight)
    }

    func tabBarViewItem(_ tabBarViewItem: TabBarViewItem, replaceContentWithDroppedStringValue: String) {

    }

    func clear() {
        self.audioState = nil
    }

}
