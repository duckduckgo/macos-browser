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
import History
import os.log

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
        if listItems.count == 1 { return 0 }

        return listItems.count
    }

    func menu(_ menu: NSMenu, update item: NSMenuItem, at index: Int, shouldCancel: Bool) -> Bool {
        guard let listItem = listItems[safe: index] else {
            Logger.general.error("Index out of bounds")
            return true
        }

        let listItemViewModel = BackForwardListItemViewModel(backForwardListItem: listItem,
                                                             faviconManagement: FaviconManager.shared,
                                                             historyCoordinating: HistoryCoordinator.shared,
                                                             isCurrentItem: index == 0)

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
        guard let listItem = listItems[safe: index] else {
            Logger.general.error("Index out of bounds")
            return
        }
        tabCollectionViewModel.selectedTabViewModel?.tab.go(to: listItem)
    }

    private var listItems: [BackForwardListItem] {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            assertionFailure("Selected tab view model is nil")
            return []
        }
        guard let currentItem = selectedTabViewModel.tab.currentHistoryItem else { return [] }

        let list = [currentItem] + (buttonType == .back
                                    ? selectedTabViewModel.tab.backHistoryItems.reversed()
                                    : selectedTabViewModel.tab.forwardHistoryItems)

        return list
    }

}
