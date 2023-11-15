//
//  BookmarkPopover.swift
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

import Cocoa

protocol BookmarkPopoverContainer: AnyObject {
    var bookmark: Bookmark? { get set }
    var bookmarkManager: BookmarkManager { get }

    func getMenuItems() -> [NSMenuItem]
    func showBookmarkAddView()
    func showFolderAddView()
    func popoverShouldClose()

}

final class BookmarkPopover: NSPopover {

    var isNew = false
    var bookmark: Bookmark?

    private weak var addressBar: NSView?

    private enum PrivateConstants {
        static let storyboard = NSStoryboard(name: "Bookmarks", bundle: nil)
        static let bookmarkAddPopoverID = "BookmarkPopoverViewController"
        static let folderAddPopoverID = "BookmarkAddFolderPopoverViewController"
    }

    /// prefferred bounding box for the popover positioning
    override var boundingFrame: NSRect {
        guard let addressBar,
              let window = addressBar.window else { return .infinite }
        var frame = window.convertToScreen(addressBar.convert(addressBar.bounds, to: nil))

        frame = frame.insetBy(dx: -36, dy: -window.frame.size.height)

        return frame
    }

    override init() {
        super.init()

        self.animates = false
        self.behavior = .transient
        setupBookmarkAddController()
    }

    required init?(coder: NSCoder) {
        fatalError("BookmarksPopover: Bad initializer")
    }

    // swiftlint:disable force_cast
    private func setupBookmarkAddController() {
        let controller = PrivateConstants.storyboard.instantiateController(withIdentifier: PrivateConstants.bookmarkAddPopoverID) as! BookmarkAddPopoverViewController
        controller.container = self
        contentViewController = controller
    }

    private func setupFolderAddController() {
        let controller = PrivateConstants.storyboard.instantiateController(withIdentifier: PrivateConstants.folderAddPopoverID) as! BookmarkAddFolderPopoverViewController
        controller.container = self
        contentViewController = controller
    }
    // swiftlint:enable force_cast

    override func show(relativeTo positioningRect: NSRect, of positioningView: NSView, preferredEdge: NSRectEdge) {
        self.addressBar = positioningView.superview
        super.show(relativeTo: positioningRect, of: positioningView, preferredEdge: preferredEdge)
    }

    private func createMenuItems(for bookmarkFolders: [BookmarkFolder], level: Int = 0) -> [NSMenuItem] {
        let viewModels = bookmarkFolders.map(BookmarkViewModel.init(entity:))
        var menuItems = [NSMenuItem]()

        for viewModel in viewModels {
            let menuItem = NSMenuItem(bookmarkViewModel: viewModel)
            menuItem.indentationLevel = level
            menuItems.append(menuItem)

            if let folder = viewModel.entity as? BookmarkFolder, !folder.children.isEmpty {
                let childFolders = folder.children.compactMap { $0 as? BookmarkFolder }
                menuItems.append(contentsOf: createMenuItems(for: childFolders, level: level + 1))
            }
        }

        return menuItems
    }

}

extension BookmarkPopover: BookmarkPopoverContainer {

    func getMenuItems() -> [NSMenuItem] {
        guard let list = bookmarkManager.list else {
            assertionFailure("Tried to refresh bookmark folder picker, but couldn't get bookmark list")
            return []
        }

        let rootFolder = NSMenuItem(title: "Bookmarks", action: nil, target: nil, keyEquivalent: "")
        rootFolder.image = NSImage(named: "Folder")

        let topLevelFolders = list.topLevelEntities.compactMap { $0 as? BookmarkFolder }
        var folderMenuItems = [NSMenuItem]()

        folderMenuItems.append(rootFolder)
        folderMenuItems.append(.separator())
        folderMenuItems.append(contentsOf: createMenuItems(for: topLevelFolders))

        return folderMenuItems
    }

    var bookmarkManager: BookmarkManager {
        LocalBookmarkManager.shared
    }

    func showBookmarkAddView() {
        setupBookmarkAddController()
    }

    func showFolderAddView() {
        setupFolderAddController()
    }

    func popoverShouldClose() {
        close()
    }

}
