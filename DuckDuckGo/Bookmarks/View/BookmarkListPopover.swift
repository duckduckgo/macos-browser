//
//  BookmarkListPopover.swift
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

final class BookmarkListPopover: NSPopover {

    private let mode: BookmarkListViewController.Mode
    private let bookmarkManager: BookmarkManager
    private var rootFolder: BookmarkFolder?

    private var preferredEdge: NSRectEdge?
    private weak var positioningView: NSView?

    private static let popoverInsets = NSEdgeInsets(top: 13, left: 13, bottom: 13, right: 13)

    @objc override func adjustFrame(_ frame: NSRect) -> NSRect {
        guard case .bookmarkBarMenu = mode else { return super.adjustFrame(frame) }
        var frame = frame
//        let boundingFrame = self.boundingFrame
//        guard !boundingFrame.isInfinite else { return frame }
//        if boundingFrame.width > frame.width {
//            frame.origin.x = min(max(frame.minX, boundingFrame.minX), boundingFrame.maxX - frame.width)
//        }
////        if boundingFrame.height > frame.height {
////            let y = min(max(frame.minY, boundingFrame.minY), boundingFrame.maxY - frame.height)
//            frame.size.height -= 400
//            frame.origin.y -= 400
////        }
//        return frame

        guard let positioningView, let mainWindow, let screenFrame = mainWindow.screen?.visibleFrame else { return frame }
        let offset = viewController.preferredContentOffset

        let windowPoint = positioningView.convert(NSPoint(x: offset.x, y: (positioningView.isFlipped ? positioningView.bounds.minY : positioningView.bounds.maxY) + offset.y), to: nil)
        let screenPoint = mainWindow.convertPoint(toScreen: windowPoint)
        if case .maxX = preferredEdge {
            // adjust the menu popover Y 16pt above the positioning view bottom edge
            frame.origin.y = min(max(screenFrame.minY, screenPoint.y - frame.size.height + 16), screenFrame.maxY)
            // align the popover height
//            frame.size.height = screenPoint.y - frame.origin.y
            //        let frame = NSRect(x: screenFrame.minX, y: screenFrame.minY, width: screenFrame.width, height: screenPoint.y - screenFrame.minY)
        } else {
            // align the menu popover content by the left edge of the positioning view but keeping the popover frame inside the screen bounds
            frame.origin.x = min(max(screenFrame.minX, screenPoint.x - Self.popoverInsets.left), screenFrame.maxX - frame.width)
            // aling the menu popover content top edge by the bottom edge of the positioning view but keeping the popover frame inside the screen bounds
            frame.origin.y = min(max(screenFrame.minY, screenPoint.y - frame.size.height - Self.popoverInsets.top), screenFrame.maxY)
        }
        return frame
    }

    init(mode: BookmarkListViewController.Mode = .popover, bookmarkManager: BookmarkManager = LocalBookmarkManager.shared, rootFolder: BookmarkFolder? = nil) {
        self.mode = mode
        self.bookmarkManager = bookmarkManager
        self.rootFolder = rootFolder

        super.init()

        if mode == .bookmarkBarMenu {
            self.shouldHideAnchor = true
        }
        self.animates = false
        self.behavior = .transient

        setupContentController()
    }

    required init?(coder: NSCoder) {
        fatalError("BookmarkListPopover: Bad initializer")
    }

    // swiftlint:disable:next force_cast
    var viewController: BookmarkListViewController { contentViewController as! BookmarkListViewController }

    private func setupContentController() {
        let controller = BookmarkListViewController(mode: mode, bookmarkManager: bookmarkManager, rootFolder: rootFolder)
        controller.delegate = self
        contentViewController = controller
    }

    func reloadData(withRootFolder rootFolder: BookmarkFolder) {
        self.rootFolder = rootFolder
        viewController.reloadData(withRootFolder: rootFolder)
    }

    override func show(relativeTo positioningRect: NSRect, of positioningView: NSView, preferredEdge: NSRectEdge) {
        self.positioningView = positioningView
        self.preferredEdge = preferredEdge
        viewController.adjustPreferredContentSize(positionedAt: preferredEdge, of: positioningView, contentInsets: Self.popoverInsets)
        super.show(relativeTo: positioningRect, of: positioningView, preferredEdge: preferredEdge)
    }

}

extension BookmarkListPopover: BookmarkListViewControllerDelegate {

    func popoverShouldClose(_ bookmarkListViewController: BookmarkListViewController) {
        close()
    }

    func popover(shouldPreventClosure: Bool) {
        behavior = shouldPreventClosure ? .applicationDefined : .transient
    }

}
