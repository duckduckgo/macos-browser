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

    var hasItemsToTheRight = false

    func tabBarViewItem(_ tabBarViewItem: DuckDuckGo_Privacy_Browser.TabBarViewItem, isMouseOver: Bool) {

    }

    func tabBarViewItemCanBePinned(_ tabBarViewItem: DuckDuckGo_Privacy_Browser.TabBarViewItem) -> Bool {
        return true
    }

    func tabBarViewItemCloseAction(_ tabBarViewItem: DuckDuckGo_Privacy_Browser.TabBarViewItem) {

    }

    func tabBarViewItemTogglePermissionAction(_ tabBarViewItem: DuckDuckGo_Privacy_Browser.TabBarViewItem) {

    }

    func tabBarViewItemCloseOtherAction(_ tabBarViewItem: DuckDuckGo_Privacy_Browser.TabBarViewItem) {

    }

    func tabBarViewItemCloseToTheRightAction(_ tabBarViewItem: DuckDuckGo_Privacy_Browser.TabBarViewItem) {

    }

    func tabBarViewItemDuplicateAction(_ tabBarViewItem: DuckDuckGo_Privacy_Browser.TabBarViewItem) {

    }

    func tabBarViewItemPinAction(_ tabBarViewItem: DuckDuckGo_Privacy_Browser.TabBarViewItem) {

    }

    func tabBarViewItemBookmarkThisPageAction(_ tabBarViewItem: DuckDuckGo_Privacy_Browser.TabBarViewItem) {

    }

    func tabBarViewItemMoveToNewWindowAction(_ tabBarViewItem: DuckDuckGo_Privacy_Browser.TabBarViewItem) {

    }

    func tabBarViewItemMoveToNewDisposableWindowAction(_ tabBarViewItem: DuckDuckGo_Privacy_Browser.TabBarViewItem) {

    }

    func tabBarViewItemFireproofSite(_ tabBarViewItem: DuckDuckGo_Privacy_Browser.TabBarViewItem) {

    }

    func tabBarViewItemRemoveFireproofing(_ tabBarViewItem: DuckDuckGo_Privacy_Browser.TabBarViewItem) {

    }

    func otherTabBarViewItemsState(for tabBarViewItem: DuckDuckGo_Privacy_Browser.TabBarViewItem) -> DuckDuckGo_Privacy_Browser.OtherTabBarViewItemsState {
        OtherTabBarViewItemsState(hasItemsToTheLeft: false, hasItemsToTheRight: hasItemsToTheRight)
    }

}
