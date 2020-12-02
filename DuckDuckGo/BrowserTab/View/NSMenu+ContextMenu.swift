//
//  NSMenu+ContextMenu.swift
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

extension NSMenu {

    static func contextMenu(forElements elements: [ContextMenuElement]) -> NSMenu {
        var menuItems = [NSMenuItem]()

        if elements.isEmpty {
            menuItems.append(.contextMenuBack)
            menuItems.append(.contextMenuForward)
            menuItems.append(.contextMenuReload)
        } else {

            // images are first in the list, but we want them at the end of the menu
            elements.reversed().forEach {
                if !menuItems.isEmpty {
                    menuItems.append(.separator())
                }

                switch $0 {

                case .link(let url):
                    NSMenuItem.linkContextMenuItems.forEach {
                        ($0 as? URLContextMenuItem)?.url = url
                        menuItems.append($0)
                    }

                case .image(let url):
                    NSMenuItem.imageContextMenuItems.forEach {
                        ($0 as? URLContextMenuItem)?.url = url
                        menuItems.append($0)
                    }

                }
            }
        }

        let menu = NSMenu()
        menuItems.forEach { menu.addItem($0) }
        return menu
    }

}
