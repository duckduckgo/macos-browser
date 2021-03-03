//
//  LinkPreviewWindowController.swift
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

import Foundation

class LinkPreviewWindowController: NSWindowController, NSToolbarDelegate {

    private let backButtonIdentifier = NSToolbarItem.Identifier("Back")
    private let forwardButtonIdentifier = NSToolbarItem.Identifier("Forward")
    private let refreshButtonIdentifier = NSToolbarItem.Identifier("Refresh")
    private let titleIdentifier = NSToolbarItem.Identifier("Title")
    private let spacerIdentifier = NSToolbarItem.Identifier("Spacer")
    private let flexibleSpacerIdentifier = NSToolbarItem.Identifier("FlexibleSpacer")

    private lazy var toolbar: NSToolbar = {
        let customToolbar = NSToolbar()
        customToolbar.sizeMode = .regular
        customToolbar.delegate = self
        customToolbar.insertItem(withItemIdentifier: backButtonIdentifier, at: 0)

        return customToolbar
    }()

    private lazy var backItem: NSToolbarItem = {
        let item = NSToolbarItem(itemIdentifier: backButtonIdentifier)
        item.image = NSImage(named: "Back")
        item.target = self
        item.action = #selector(back(_:))
        item.maxSize = NSSize(width: 16, height: 16)
        return item
    }()

    private lazy var forwardItem: NSToolbarItem = {
        let item = NSToolbarItem(itemIdentifier: forwardButtonIdentifier)
        item.image = NSImage(named: "Forward")
        item.target = self
        item.action = #selector(forward(_:))
        item.maxSize = NSSize(width: 16, height: 16)
        return item
    }()

    private lazy var refreshItem: NSToolbarItem = {
        let item = NSToolbarItem(itemIdentifier: refreshButtonIdentifier)
        item.image = NSImage(named: "Refresh")
        item.target = self
        item.action = #selector(refresh(_:))
        item.maxSize = NSSize(width: 16, height: 16)
        return item
    }()

    private lazy var titleItem: NSToolbarItem = {
        let item = NSToolbarItem(itemIdentifier: titleIdentifier)
        item.title = "Web View Title Goes Here Web View Title Goes Here Web View Title Goes Here Web View Title Goes Here"
        item.target = self
        return item
    }()

    init() {
        super.init(window: nil)

        /* Load window from xib file */
        Bundle.main.loadNibNamed("LinkPreviewWindowController", owner: self, topLevelObjects: nil)

        print("Loaded with window: \(self.window)")

        window?.titlebarAppearsTransparent = true
        window?.titleVisibility = .hidden
        window?.toolbar = self.toolbar
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func back(_ sender: NSToolbarItem) {
        print("Back")
    }

    @objc func forward(_ sender: NSToolbarItem) {
        print("Forward")
    }

    @objc func refresh(_ sender: NSToolbarItem) {
        print("Refresh")
    }

    func toolbar(_ toolbar: NSToolbar,
                 itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch itemIdentifier {

        case backButtonIdentifier: return backItem
        case forwardButtonIdentifier: return forwardItem
        case refreshButtonIdentifier: return refreshItem
        case titleIdentifier: return titleItem

        case spacerIdentifier:
            let item = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier.space)
            item.maxSize = CGSize(width: 2, height: 16)
            return item

        case flexibleSpacerIdentifier:
            let item = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier.flexibleSpace)
            item.minSize = CGSize(width: 2, height: 16)
            return item

        default: return nil
        }
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [
            backButtonIdentifier,
            spacerIdentifier,
            forwardButtonIdentifier,
            spacerIdentifier,
            refreshButtonIdentifier,
            flexibleSpacerIdentifier,
            titleIdentifier,
            flexibleSpacerIdentifier
        ]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [
            backButtonIdentifier,
            spacerIdentifier,
            forwardButtonIdentifier,
            spacerIdentifier,
            refreshButtonIdentifier,
            flexibleSpacerIdentifier,
            titleIdentifier,
            flexibleSpacerIdentifier
        ]
    }

    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        []
    }

    func toolbarWillAddItem(_ notification: Notification) {

    }

    func toolbarDidRemoveItem(_ notification: Notification) {

    }

}

class LinkPreviewWindow: NSWindow {

}
