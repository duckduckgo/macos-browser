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

protocol BookmarkListPopoverDelegate: NSPopoverDelegate {
    func openNextBookmarksMenu(_ sender: BookmarkListPopover)
    func openPreviousBookmarksMenu(_ sender: BookmarkListPopover)
}

final class BookmarkListPopover: NSPopover {

    override init() {
        super.init()

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
        let controller = BookmarkListViewController()
        controller.delegate = self
        contentViewController = controller
    }

    override func show(relativeTo positioningRect: NSRect, of positioningView: NSView, preferredEdge: NSRectEdge) {
        viewController.adjustPreferredContentSize(positionedRelativeTo: positioningRect, of: positioningView, at: preferredEdge)
        super.show(relativeTo: positioningRect, of: positioningView, preferredEdge: preferredEdge)
    }
}

extension BookmarkListPopover: BookmarkListViewControllerDelegate {

    func closeBookmarksPopover(_ sender: BookmarkListViewController) {
        close()
    }

    func popover(shouldPreventClosure: Bool) {
        behavior = shouldPreventClosure ? .applicationDefined : .transient
    }

}
