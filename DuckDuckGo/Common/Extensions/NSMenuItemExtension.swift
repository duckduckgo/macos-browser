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

extension NSMenuItem {

    static var empty: NSMenuItem {
        let item = NSMenuItem(title: UserText.bookmarksBarFolderEmpty)
        item.isEnabled = false
        return item
    }

    convenience init(title string: String, action selector: Selector? = nil, target: AnyObject? = nil, keyEquivalent: [KeyEquivalentElement] = [], representedObject: Any? = nil, items: [NSMenuItem]? = nil) {
        self.init(title: string, action: selector, keyEquivalent: keyEquivalent.charCode)
        if !keyEquivalent.modifierMask.isEmpty {
            self.keyEquivalentModifierMask = keyEquivalent.modifierMask
        }
        self.target = target
        self.representedObject = representedObject

        if let items {
            self.submenu = NSMenu(title: title, items: items)
        }
    }

    convenience init(title string: String, action selector: Selector? = nil, target: AnyObject? = nil, keyEquivalent: [KeyEquivalentElement] = [], representedObject: Any? = nil, @MenuBuilder items: () -> [NSMenuItem]) {
        self.init(title: string, action: selector, target: target, keyEquivalent: keyEquivalent, representedObject: representedObject, items: items())
    }

    convenience init(action selector: Selector?) {
        self.init()
        self.action = selector
    }

    convenience init(bookmarkViewModel: BookmarkViewModel) {
        self.init()

        title = bookmarkViewModel.menuTitle
        image = bookmarkViewModel.menuFavicon
        representedObject = bookmarkViewModel.entity
        action = #selector(MainViewController.openBookmark(_:))
    }

    convenience init(bookmarkViewModels: [BookmarkViewModel]) {
        self.init()

        title = UserText.bookmarksOpenInNewTabs
        representedObject = bookmarkViewModels
        action = #selector(MainViewController.openAllInTabs(_:))
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

}

enum KeyEquivalentElement: ExpressibleByStringLiteral {
    public typealias StringLiteralType = String

    case charCode(String)
    case command
    case shift
    case option
    case control

    static let backspace = KeyEquivalentElement.charCode("\u{8}")
    static let tab = KeyEquivalentElement.charCode("\t")
    static let left = KeyEquivalentElement.charCode("\u{2190}")
    static let right = KeyEquivalentElement.charCode("\u{2192}")

    init(stringLiteral value: String) {
        self = .charCode(value)
    }
}

extension [KeyEquivalentElement]: ExpressibleByStringLiteral, ExpressibleByUnicodeScalarLiteral, ExpressibleByExtendedGraphemeClusterLiteral {
    public typealias StringLiteralType = String

    public init(stringLiteral value: String) {
        self = [.charCode(value)]
    }

    var charCode: String {
        for item in self {
            if case .charCode(let value) = item {
                return value
            }
        }
        return ""
    }

    var modifierMask: NSEvent.ModifierFlags {
        var result: NSEvent.ModifierFlags = []
        for item in self {
            switch item {
            case .charCode: continue
            case .command:
                result.insert(.command)
            case .shift:
                result.insert(.shift)
            case .option:
                result.insert(.option)
            case .control:
                result.insert(.control)
            }
        }
        return result
    }

}
