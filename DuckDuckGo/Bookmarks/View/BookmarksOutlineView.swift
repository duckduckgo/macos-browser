//
//  BookmarksOutlineView.swift
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

final class BookmarksOutlineView: NSOutlineView {

    private var highlightedRowView: RoundedSelectionRowView?
    private var highlightedCellView: BookmarkOutlineCellView?

    @PublishedAfter var highlightedRow: Int? {
        didSet {
            highlightedRowView?.highlight = false
            highlightedCellView?.highlight = false
            guard let row = highlightedRow, row < numberOfRows else { return }
            if case .keyDown = NSApp.currentEvent?.type {
                scrollRowToVisible(row)
            }

            let item = item(atRow: row) as? BookmarkNode
            let isInKeyPopover = self.isInKeyPopover
            let rowView = rowView(atRow: row, makeIfNecessary: false) as? RoundedSelectionRowView
            rowView?.isInKeyWindow = isInKeyPopover
            rowView?.highlight = item?.canBeHighlighted ?? false
            highlightedRowView = rowView

            let cellView = self.view(atColumn: 0, row: row, makeIfNecessary: false) as? BookmarkOutlineCellView
            cellView?.isInKeyWindow = isInKeyPopover
            cellView?.highlight = item?.canBeHighlighted ?? false
            highlightedCellView = cellView

            var window = window
            while let windowParent = window?.parent,
                  type(of: windowParent) == type(of: window!),
                  let scrollView = windowParent.contentView?.subviews.first(where: { $0 is NSScrollView }) as? NSScrollView,
                  let outlineView = scrollView.documentView as? Self {
                window = windowParent

                outlineView.highlightedRowView?.isInKeyWindow = false
                outlineView.highlightedCellView?.isInKeyWindow = false
            }
        }
    }

    private var isInKeyPopover: Bool {
        if window?.childWindows?.first(where: { child in
            if type(of: child) == type(of: window!),
               let scrollView = child.contentView?.subviews.first(where: { $0 is NSScrollView }) as? NSScrollView,
               let outlineView = scrollView.documentView as? Self,
               outlineView.highlightedRow != nil {
                true
            } else {
                false
            }
        }) != nil {
            return false
        }
        return true
    }

    override var clickedRow: Int {
        let clickedRow = super.clickedRow
        if clickedRow != -1 {
            return clickedRow
        }
        return self.withMouseLocationInViewCoordinates { point in
            self.row(at: point)
        } ?? -1
    }

    override func frameOfOutlineCell(atRow row: Int) -> NSRect {
        let frame = super.frameOfOutlineCell(atRow: row)

        guard let node = item(atRow: row) as? BookmarkNode else {
            return frame
        }

        if node.representedObject is SpacerNode {
            return .zero
        }

        guard node.representedObject is PseudoFolder else {
            return frame
        }

        if node.childNodes.isEmpty {
            return .zero
        } else {
            return frame
        }
    }

    override func viewDidMoveToWindow() {
        highlightedRow = nil

        super.viewDidMoveToWindow()
        guard let scrollView = enclosingScrollView else { return }

        let trackingArea = NSTrackingArea(rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self, userInfo: nil)

        scrollView.addTrackingArea(trackingArea)
    }

    override func mouseMoved(with event: NSEvent) {
        updateHighlightedRowUnderCursor()
    }

    override func mouseExited(with event: NSEvent) {
        let windowNumber = NSWindow.windowNumber(at: NSEvent.mouseLocation, belowWindowWithWindowNumber: 0)
        if let window = NSApp.window(withWindowNumber: windowNumber),
           window.contentViewController?.nextResponder is NSPopover {

            highlightedRowView?.isInKeyWindow = false
            highlightedCellView?.isInKeyWindow = false
        } else {
            highlightedRow = nil
        }
    }

    func scrollTo(_ item: Any, code: ((Int) -> Void)? = nil) {
        let rowIndex = row(forItem: item)

        if rowIndex != -1 {
            scrollRowToVisible(rowIndex)
            code?(rowIndex)
        }
    }

    /// Scrolls to the passed node and tries to position it in the second row.
    func scrollToAdjustedPositionInOutlineView(_ item: Any) {
        scrollTo(item) { rowIndex in
            if let enclosingScrollView = self.enclosingScrollView {
                let rowRect = self.rect(ofRow: rowIndex)
                let desiredTopPosition = rowRect.origin.y - self.rowHeight // Adjusted position one row height from the top.
                let scrollPoint = NSPoint(x: 0, y: desiredTopPosition - enclosingScrollView.contentInsets.top)
                enclosingScrollView.contentView.scroll(to: scrollPoint)
            }
        }
    }

    func highlight(_ item: Any) {
        let row = row(forItem: item)
        guard let rowView = rowView(atRow: row, makeIfNecessary: false) as? RoundedSelectionRowView else { return }

        rowView.highlight = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            rowView.highlight = false
        }
    }

    func updateHighlightedRowUnderCursor() {
        let point = mouseLocationInsideBounds()
        let row = point.map { self.row(at: NSPoint(x: self.bounds.midX, y: $0.y)) } ?? -1
        guard row >= 0, row < NSNotFound else {
            highlightedRow = nil
            return
        }
        if highlightedRow != row {
            highlightedRow = row
        } else {
            highlightedRowView?.isInKeyWindow = true
            highlightedCellView?.isInKeyWindow = true
        }
    }

    func isItemVisible(_ item: Any) -> Bool {
        let rowIndex = self.row(forItem: item)

        if rowIndex == -1 {
            return false
        }

        let visibleRowsRange = self.rows(in: self.visibleRect)
        return visibleRowsRange.contains(rowIndex)
    }

    override func validateProposedFirstResponder(_ responder: NSResponder, for event: NSEvent?) -> Bool {
        if event?.type == .rightMouseDown {
            // always allow context menu on a cell
            return true
        }
        return super.validateProposedFirstResponder(responder, for: event)
    }

}
