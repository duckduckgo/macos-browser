//
//  NavigationButtonMenuDelegate.swift
//
//  Copyright © 2020 DuckDuckGo. All rights reserved.
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

import Cocoa
import os.log
import WebKit

final class NavigationButtonMenuDelegate: NSObject {

    enum ButtonType: Equatable {
        case back
        case forward
    }

    private let buttonType: ButtonType
    private let tabCollectionViewModel: TabCollectionViewModel

    init(buttonType: ButtonType, tabCollectionViewModel: TabCollectionViewModel) {
        self.buttonType = buttonType
        self.tabCollectionViewModel = tabCollectionViewModel
    }

}

extension NavigationButtonMenuDelegate: NSMenuDelegate {

    func numberOfItems(in _: NSMenu) -> Int {
        if listItems.count > 1 {
            return listItems.count
        } else if tabCollectionViewModel.selectedTabViewModel?.tab.canBeClosedWithBack == true {
            return 1
        }
        return 0
    }

    func menu(_: NSMenu, update item: NSMenuItem, at index: Int, shouldCancel _: Bool) -> Bool {
        let listItems = listItems
        let listItem: BackForwardListItem
        if
            listItems.count > 1,
            let item = listItems[safe: index] {
            listItem = .backForwardListItem(item)
        } else if let parentTab = tabCollectionViewModel.selectedTabViewModel?.tab.parentTab {
            listItem = .goBackToCloseItem(parentTab: parentTab)
        } else {
            os_log("%s: Index out of bounds", type: .error, className)
            return true
        }

        let listItemViewModel = WKBackForwardListItemViewModel(
            backForwardListItem: listItem,
            faviconManagement: FaviconManager.shared,
            historyCoordinating: HistoryCoordinator.shared,
            isCurrentItem: listItems[safe: index] === currentListItem)

        item.title = listItemViewModel.title
        item.image = listItemViewModel.image
        item.state = listItemViewModel.state

        item.target = self
        item.action = listItemViewModel.isGoBackToCloseItem ? #selector(goBackAction(_:)) : #selector(menuItemAction(_:))
        item.tag = index
        return true
    }

    @objc
    func menuItemAction(_ sender: NSMenuItem) {
        let index = sender.tag
        let listItems = listItems

        guard index < listItems.count else {
            os_log("%s: Index out of bounds", type: .error, className)
            return
        }
        let listItem = listItems[index]

        guard listItem !== currentListItem else {
            // current item selected: do nothing
            return
        }
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("%s: Selected tab view model is nil", type: .error, className)
            return
        }

        selectedTabViewModel.tab.go(to: listItem)
    }

    @objc
    func goBackAction(_: NSMenuItem) {
        tabCollectionViewModel.selectedTabViewModel?.tab.goBack()
    }

    private var listItems: [WKBackForwardListItem] {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("%s: Selected tab view model is nil", type: .error, className)
            return []
        }

        let backForwardList = selectedTabViewModel.tab.webView.backForwardList
        var list = buttonType == .back ? backForwardList.backList.reversed() : backForwardList.forwardList

        guard let currentItem = selectedTabViewModel.tab.webView.backForwardList.currentItem else {
            return list
        }
        list.insert(currentItem, at: 0)

        return list
    }

    private var currentListItem: WKBackForwardListItem? {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("%s: Selected tab view model is nil", type: .error, className)
            return nil
        }

        return selectedTabViewModel.tab.webView.backForwardList.currentItem
    }

}
