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
import Common
import WebKit

@MainActor
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

    func numberOfItems(in menu: NSMenu) -> Int {
        let listItems = listItems

        // Don't show menu if there is just the current item
        if listItems.items.count == 0 || (listItems.items.count == 1 && listItems.currentIndex == 0) { return 0 }

        return listItems.items.count
    }

    func menu(_ menu: NSMenu, update item: NSMenuItem, at index: Int, shouldCancel: Bool) -> Bool {
        let (listItems, currentIndex) = self.listItems
        guard let listItem = listItems[safe: index] else {
            os_log("%s: Index out of bounds", type: .error, className)
            return true
        }

        let listItemViewModel = WKBackForwardListItemViewModel(backForwardListItem: listItem,
                                                               faviconManagement: FaviconManager.shared,
                                                               historyCoordinating: HistoryCoordinator.shared,
                                                               isCurrentItem: index == currentIndex)

        item.title = listItemViewModel.title
        item.image = listItemViewModel.image
        item.state =  listItemViewModel.state

        item.target = self
        item.action = #selector(menuItemAction(_:))
        item.tag = index
        return true
    }

    @MainActor
    @objc func menuItemAction(_ sender: NSMenuItem) {
        let index = sender.tag
        let (listItems, currentIndex) = self.listItems
        guard let listItem = listItems[safe: index] else {
            os_log("%s: Index out of bounds", type: .error, className)
            return
        }

        guard currentIndex != index else {
            // current item selected: do nothing
            return
        }
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("%s: Selected tab view model is nil", type: .error, className)
            return
        }

        switch listItem {
        case .backForwardListItem(let wkListItem):
            selectedTabViewModel.tab.go(to: wkListItem)
        case .goBackToCloseItem(parentTab:):
            tabCollectionViewModel.selectedTabViewModel?.tab.goBack()
        case .error:
            break
        }
    }

    private var listItems: (items: [BackForwardListItem], currentIndex: Int?) {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("%s: Selected tab view model is nil", type: .error, className)
            return ([], nil)
        }

        let backForwardList = selectedTabViewModel.tab.webView.backForwardList
        let wkList = buttonType == .back ? backForwardList.backList.reversed() : backForwardList.forwardList
        var list = wkList.map { BackForwardListItem.backForwardListItem($0) }
        var currentIndex: Int?

        // Add closing with back button to the list
        if list.count == 0,
            let parentTab = selectedTabViewModel.tab.parentTab,
            buttonType == .back {
            list.insert(.goBackToCloseItem(parentTab: parentTab), at: 0)
        }

        // Add current item to the list
        if let currentItem = selectedTabViewModel.tab.webView.backForwardList.currentItem {
            list.insert(.backForwardListItem(currentItem), at: 0)
            currentIndex = 0
        }

        // Add error to the list
        if selectedTabViewModel.tab.error != nil {
            if buttonType == .back {
                list.insert(.error, at: 0)
                currentIndex = 0
            } else {
                list = []
                currentIndex = nil
            }
        }

        return (list, currentIndex)
    }

}
