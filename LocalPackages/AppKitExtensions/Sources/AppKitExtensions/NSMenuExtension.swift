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

import AppKit
import Utilities

typealias MenuBuilder = ArrayBuilder<NSMenuItem>

public extension NSMenu {

    convenience init(title: String = "", items: [NSMenuItem]) {
        self.init(title: title)
        self.items = items
    }

    convenience init(title string: String = "", @MenuBuilder items: () -> [NSMenuItem]) {
        self.init(title: string, items: items())
    }

    @discardableResult
    func buildItems(@MenuBuilder items: () -> [NSMenuItem]) -> NSMenu {
        self.items = items()
        return self
    }

    func indexOfItem(withIdentifier id: String) -> Int? {
        return items.enumerated().first(where: { $0.element.identifier?.rawValue == id })?.offset
    }

    func indexOfItem(with action: Selector) -> Int? {
        return items.enumerated().first(where: { $0.element.action == action })?.offset
    }

    func item(with action: Selector) -> NSMenuItem? {
        return indexOfItem(with: action).map { self.items[$0] }
    }

    func replaceItem(at index: Int, with newItem: NSMenuItem) {
        removeItem(at: index)
        insertItem(newItem, at: index)
    }

    /// Pops up the menu at the current mouse location.
    ///
    /// - Parameter view: The view to display the menu item over.
    /// - Attention: If the view is not currently installed in a window, this function does not show any pop up menu.
    func popUpAtMouseLocation(in view: NSView) {
        guard let cursorLocation = view.window?.mouseLocationOutsideOfEventStream else { return }
        let convertedLocation = view.convert(cursorLocation, from: nil)
        popUp(positioning: nil, at: convertedLocation, in: view)
    }

}
