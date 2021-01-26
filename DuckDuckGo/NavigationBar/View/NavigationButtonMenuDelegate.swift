//
//  NavigationButtonMenu.swift
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

class NavigationButtonMenuDelegate: NSObject {

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
        return listItems.count > 1 ? listItems.count : 0
    }

    func menu(_ menu: NSMenu, update item: NSMenuItem, at index: Int, shouldCancel: Bool) -> Bool {
        let listItems = self.listItems
        guard index < listItems.count else {
            os_log("%s: Index out of bounds", type: .error, className)
            return true
        }

        let listItem = listItems[index]
        let listItemViewModel = WKBackForwardListItemViewModel(backForwardListItem: listItem, faviconService: LocalFaviconService.shared)

        item.title = listItemViewModel.title
        item.image = listItemViewModel.image

        item.state = listItem == currentListItem ? .on : .off
        item.target = self
        item.action = #selector(menuItemAction(_:))
        item.tag = index
        return true
    }

    @objc func menuItemAction(_ sender: NSMenuItem) {
        let index = sender.tag
        let listItems = self.listItems

        guard index < listItems.count else {
            os_log("%s: Index out of bounds", type: .error, className)
            return
        }
        let listItem = listItems[index]

        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("%s: Selected tab view model is nil", type: .error, className)
            return
        }

        selectedTabViewModel.webView.go(to: listItem)
    }

    private var listItems: [WKBackForwardListItem] {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("%s: Selected tab view model is nil", type: .error, className)
            return []
        }

        let backForwardList = selectedTabViewModel.webView.backForwardList
        var list = buttonType == .back ? backForwardList.backList.reversed() : backForwardList.forwardList

        guard let currentItem = selectedTabViewModel.webView.backForwardList.currentItem else {
            os_log("%s: Current item is nil", type: .error, className)
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

        return selectedTabViewModel.webView.backForwardList.currentItem
    }

}
