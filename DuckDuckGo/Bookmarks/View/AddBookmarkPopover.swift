//
//  AddBookmarkPopover.swift
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
import SwiftUI

final class AddBookmarkPopover: NSPopover {

    var isNew: Bool = false
    var bookmark: Bookmark? {
        didSet {
            setupBookmarkAddController()
        }
    }

    private weak var addressBar: NSView?

    /// prefferred bounding box for the popover positioning
    override var boundingFrame: NSRect {
        guard let addressBar,
              let window = addressBar.window else { return .infinite }
        var frame = window.convertToScreen(addressBar.convert(addressBar.bounds, to: nil))

        frame = frame.insetBy(dx: -42, dy: -window.frame.size.height)

        return frame
    }

    override init() {
        super.init()

        animates = false
        behavior = .transient
    }

    required init?(coder: NSCoder) {
        fatalError("BookmarksPopover: Bad initializer")
    }

    private func setupBookmarkAddController() {
        guard let bookmark else { return }
        contentViewController = NSHostingController(rootView: AddBookmarkPopoverView(model: AddBookmarkPopoverViewModel(bookmark: bookmark))
            .legacyOnDismiss { [weak self] in
                self?.performClose(nil)
            })
    }

    override func show(relativeTo positioningRect: NSRect, of positioningView: NSView, preferredEdge: NSRectEdge) {
        self.addressBar = positioningView.superview
        super.show(relativeTo: positioningRect, of: positioningView, preferredEdge: preferredEdge)
    }

    override func performClose(_ sender: Any?) {
        self.close()
    }

    func popoverWillClose() {
        bookmark = nil
    }

}
