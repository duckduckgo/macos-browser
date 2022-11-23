//
//  NSMenuExtension.swift
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

    convenience init(items: [NSMenuItem]) {
        self.init()

        items.forEach { item in
            addItem(item)
        }
    }

    func index(ofItemWithIdentifier id: String) -> Int? {
        guard let item = items.first(where: { $0.identifier?.rawValue == id }) else { return nil }
        return index(of: item)
    }

    func item(with identifier: WKMenuItemIdentifier) -> NSMenuItem? {
        return index(ofItemWithIdentifier: identifier.rawValue).map { self.items[$0] }
    }

    func replaceItem(at index: Int, with newItem: NSMenuItem) {
        removeItem(at: index)
        insertItem(newItem, at: index)
    }

}
