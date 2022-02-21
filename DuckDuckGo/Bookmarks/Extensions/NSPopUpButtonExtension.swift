//
//  NSPopUpButtonExtension.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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

import AppKit
import Combine

extension NSPopUpButton {

    var selectionPublisher: AnyPublisher<Int, Never> {
        NotificationCenter.default
            .publisher(for: NSMenu.didSendActionNotification, object: menu)
            .map { _ in self.indexOfSelectedItem }
            .prepend(self.indexOfSelectedItem)
            .eraseToAnyPublisher()
    }

    func displayBrowserTabButtons(withSelectedTab tabType: Tab.TabContent) {
        removeAllItems()

        var selectedTabIndex: Int?

        for (index, type) in Tab.TabContent.displayableTabTypes.enumerated() {
            guard let tabTitle = type.title else {
                assertionFailure("Attempted to display standard tab type in tab switcher")
                return
            }

            addItem(withTitle: tabTitle)

            if type == tabType {
                selectedTabIndex = index
            }
        }

        selectItem(at: selectedTabIndex ?? 0)
    }

    func select(tabType: Tab.TabContent) {
        guard let title = tabType.title else {
            return
        }

        selectItem(withTitle: title)
    }

}
