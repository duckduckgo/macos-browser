//
//  ApplicationDockMenu.swift
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

protocol ApplicationDockMenuDataSource: AnyObject {

    func numberOfWindowMenuItems(in applicationDockMenu: ApplicationDockMenu) -> Int
    func applicationDockMenu(_ applicationDockMenu: ApplicationDockMenu, windowTitleFor windowMenuItemIndex: Int) -> String
    func indexOfSelectedWindowMenuItem(in applicationDockMenu: ApplicationDockMenu) -> Int?

}

protocol ApplicationDockMenuDelegate: AnyObject {

    func applicationDockMenu(_ applicationDockMenu: ApplicationDockMenu, selectWindowWith index: Int)

}

final class ApplicationDockMenu: NSMenu {

    weak var dataSource: ApplicationDockMenuDataSource? {
        didSet {
            reloadData()
        }
    }

    weak var applicationDockMenuDelegate: ApplicationDockMenuDelegate?

    func reloadData() {
        removeAllItems()

        guard let dataSource = dataSource else { return }

        let numberOfWindowMenuItems = dataSource.numberOfWindowMenuItems(in: self)
        let selectedIndex = dataSource.indexOfSelectedWindowMenuItem(in: self)

        for index in 0..<numberOfWindowMenuItems {
            let windowItemTitle = dataSource.applicationDockMenu(self, windowTitleFor: index)
            let windowItem = NSMenuItem(title: windowItemTitle, action: #selector(menuItemAction(_:)), keyEquivalent: "")
            windowItem.target = self
            windowItem.state = index == selectedIndex ? .on : .mixed
            addItem(windowItem)
        }

        if numberOfWindowMenuItems > 0 {
            addItem(.separator())
        }

        let newWindowItem = NSMenuItem(title: UserText.newWindowMenuItem,
                                       action: #selector(AppDelegate.newWindow(_:)),
                                       target: nil,
                                       keyEquivalent: "")
        addItem(newWindowItem)
    }

    @objc func menuItemAction(_ sender: Any?) {
        guard let menuItem = sender as? NSMenuItem else {
            os_log("ApplicationDockMenu: Sender is not instance of NSMenuItem", type: .error)
            return
        }
        guard let index = items.firstIndex(of: menuItem) else {
            os_log("ApplicationDockMenu: NSMenuItem not part of this menu", type: .error)
            return
        }
        applicationDockMenuDelegate?.applicationDockMenu(self, selectWindowWith: index)
    }

}
