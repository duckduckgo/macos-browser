//
//  BookmarksBarMenuPopover.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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
import Foundation

protocol BookmarksBarMenuPopoverDelegate: NSPopoverDelegate {
    func openNextBookmarksMenu(_ sender: BookmarksBarMenuPopover)
    func openPreviousBookmarksMenu(_ sender: BookmarksBarMenuPopover)
}

final class BookmarksBarMenuPopover: NSPopover {

    private let bookmarkManager: BookmarkManager
    private(set) var rootFolder: BookmarkFolder?

    private(set) var preferredEdge: NSRectEdge?

    private var bookmarksMenuPopoverDelegate: BookmarksBarMenuPopoverDelegate? {
        delegate as? BookmarksBarMenuPopoverDelegate
    }

    static let popoverInsets = NSEdgeInsets(top: 13, left: 13, bottom: 13, right: 13)

    init(bookmarkManager: BookmarkManager = LocalBookmarkManager.shared, rootFolder: BookmarkFolder? = nil) {
        self.bookmarkManager = bookmarkManager
        self.rootFolder = rootFolder

        super.init()

        self.shouldHideAnchor = true
        self.animates = false
        self.behavior = .transient

        setupContentController()
    }

    required init?(coder: NSCoder) {
        fatalError("BookmarksBarMenuPopover: Bad initializer")
    }

    // swiftlint:disable:next force_cast
    var viewController: BookmarksBarMenuViewController { contentViewController as! BookmarksBarMenuViewController }

    private func setupContentController() {
        let controller = BookmarksBarMenuViewController(bookmarkManager: bookmarkManager, rootFolder: rootFolder)
        controller.delegate = self
        contentViewController = controller
    }

    func reloadData(withRootFolder rootFolder: BookmarkFolder) {
        self.rootFolder = rootFolder
        viewController.reloadData(withRootFolder: rootFolder)
    }

    override func show(relativeTo positioningRect: NSRect, of positioningView: NSView, preferredEdge: NSRectEdge) {
        Self.closeBookmarkListPopovers(shownIn: mainWindow, except: self)

        var positioningView = positioningView
        var positioningRect = positioningRect
        // add temporary view to bookmarks menu table to prevent popover jumping on table reloading
        // showing the popover against coordinates in the table view breaks popover positioning
        // the view will be removed in `close()`
        if positioningView is NSTableCellView,
           let tableView = positioningView.superview?.superview as? NSTableView {
            let v = NSView(frame: positioningView.convert(positioningRect, to: tableView))
            positioningRect = v.bounds
            positioningView = v
            tableView.addSubview(v)
        }

        self.preferredEdge = preferredEdge
        viewController.adjustPreferredContentSize(positionedRelativeTo: positioningRect, of: positioningView, at: preferredEdge)
        super.show(relativeTo: positioningRect, of: positioningView, preferredEdge: preferredEdge)
    }

    /// Adjust bookmarks bar menu popover frame
    @objc override func adjustFrame(_ frame: NSRect) -> NSRect {
        guard let positioningView, let mainWindow, let screenFrame = mainWindow.screen?.visibleFrame else { return frame }
        let offset = viewController.preferredContentOffset
        var frame = frame

        let windowPoint = positioningView.convert(NSPoint(x: offset.x, y: (positioningView.isFlipped ? positioningView.bounds.minY : positioningView.bounds.maxY) + offset.y), to: nil)
        let screenPoint = mainWindow.convertPoint(toScreen: windowPoint)

        if case .maxX = preferredEdge { // submenu
            // adjust the menu popover Y 16pt above the positioning view bottom edge
            frame.origin.y = min(max(screenFrame.minY, screenPoint.y - frame.size.height + 36), screenFrame.maxY)

        } else { // context menu
            // align the menu popover content by the left edge of the positioning view but keeping the popover frame inside the screen bounds
            frame.origin.x = min(max(screenFrame.minX, screenPoint.x - Self.popoverInsets.left), screenFrame.maxX - frame.width)
            // aling the menu popover content top edge by the bottom edge of the positioning view but keeping the popover frame inside the screen bounds
            frame.origin.y = min(max(screenFrame.minY, screenPoint.y - frame.size.height - Self.popoverInsets.top), screenFrame.maxY)
        }
        return frame
    }

    /// close other `BookmarksBarMenuPopover`-s and `BookmarkListPopover`-s shown from the main window when opening a new one
    static func closeBookmarkListPopovers(shownIn window: NSWindow?, except popoverToKeep: BookmarksBarMenuPopover? = nil) {
        guard let window,
              // ignore when opening a submenu from another BookmarkListPopover
              !(window.contentViewController?.nextResponder is Self) else { return }
        for case let .some(popover as NSPopover) in (window.childWindows ?? []).map(\.contentViewController?.nextResponder) where popover !== popoverToKeep && popover.isShown {
            popover.close()
        }
    }

    override func close() {
        // remove temporary positioning view from bookmarks menu table
        if let positioningView, positioningView.superview is NSTableView {
            positioningView.removeFromSuperview()
        }
        super.close()
    }

}

extension BookmarksBarMenuPopover: BookmarksBarMenuViewControllerDelegate {

    func closeBookmarksPopovers(_ sender: BookmarksBarMenuViewController) {
        var window = sender.view.window
        // find root BookmarkListPopover in Bookmarks menu structure
        while let parent = window?.parent, parent.contentViewController?.nextResponder is Self {
            window = parent
        }
        guard let popover = window?.contentViewController?.nextResponder as? Self else {
            assertionFailure("Expected BookmarkListPopover as \(window?.debugDescription ?? "<nil>")‘s contentViewController nextResponder")
            return
        }
        // close root BookmarkListPopover
        popover.close()
    }

    func popover(shouldPreventClosure: Bool) {
        var window = contentViewController?.view.window
        while let popover = window?.contentViewController?.nextResponder as? Self {
            popover.behavior = shouldPreventClosure ? .applicationDefined : .transient
            window = window?.parent
        }
    }

    func openNextBookmarksMenu(_ sender: BookmarksBarMenuViewController) {
        bookmarksMenuPopoverDelegate?.openNextBookmarksMenu(self)
    }

    func openPreviousBookmarksMenu(_ sender: BookmarksBarMenuViewController) {
        bookmarksMenuPopoverDelegate?.openPreviousBookmarksMenu(self)
    }

}
