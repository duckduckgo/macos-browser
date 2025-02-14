//
//  NSMenuItemExtension.swift
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

public extension NSMenuItem {

    convenience init(title string: String, action selector: Selector? = nil, target: AnyObject? = nil, keyEquivalent: NSEvent.KeyEquivalent = [], representedObject: Any? = nil, state: NSControl.StateValue = .off, items: [NSMenuItem]? = nil) {
        self.init(title: string, action: selector, keyEquivalent: keyEquivalent.charCode)
        if !keyEquivalent.modifierMask.isEmpty {
            self.keyEquivalentModifierMask = keyEquivalent.modifierMask
        }
        self.target = target
        self.representedObject = representedObject
        self.state = state

        if let items {
            self.submenu = NSMenu(title: title, items: items)
        }
    }

    convenience init(title string: String, action selector: Selector? = nil, target: AnyObject? = nil, keyEquivalent: NSEvent.KeyEquivalent = [], representedObject: Any? = nil, state: NSControl.StateValue = .off, @MenuBuilder items: () -> [NSMenuItem]) {
        self.init(title: string, action: selector, target: target, keyEquivalent: keyEquivalent, representedObject: representedObject, state: state, items: items())
    }

    convenience init(action selector: Selector?) {
        self.init()
        self.action = selector
    }

    convenience init(title: String) {
        self.init(title: title, action: nil, keyEquivalent: "")
    }

    var topMenu: NSMenu? {
        var menuItem = self
        while let parent = menuItem.parent {
            menuItem = parent
        }

        return menuItem.menu
    }

    func removeFromParent() {
        parent?.submenu?.removeItem(self)
    }

    @discardableResult
    func alternate() -> NSMenuItem {
        self.isAlternate = true
        return self
    }

    @discardableResult
    func hidden() -> NSMenuItem {
        self.isHidden = true
        if !keyEquivalent.isEmpty {
            self.allowsKeyEquivalentWhenHidden = true
        }
        return self
    }

    @discardableResult
    func submenu(_ submenu: NSMenu) -> NSMenuItem {
        self.submenu = submenu
        return self
    }

    @discardableResult
    func withImage(_ image: NSImage?) -> NSMenuItem {
        self.image = image
        return self
    }

    @discardableResult
    func targetting(_ target: AnyObject) -> NSMenuItem {
        self.target = target
        return self
    }

    @discardableResult
    func withSubmenu(_ submenu: NSMenu) -> NSMenuItem {
        self.submenu = submenu
        return self
    }

    @discardableResult
    func withModifierMask(_ mask: NSEvent.ModifierFlags) -> NSMenuItem {
        self.keyEquivalentModifierMask = mask
        return self
    }

    @discardableResult
    func withIdentifier(_ identifier: NSUserInterfaceItemIdentifier) -> NSMenuItem {
        self.identifier = identifier
        return self
    }

}
