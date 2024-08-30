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
import Carbon

protocol BookmarksOutlineViewDataSource: NSOutlineViewDataSource {
    func firstHighlightableRow(for _: BookmarksOutlineView) -> Int?
    func nextHighlightableRow(inNextSection: Bool, for _: BookmarksOutlineView, after row: Int) -> Int?
    func previousHighlightableRow(inPreviousSection: Bool, for _: BookmarksOutlineView, before row: Int) -> Int?
    func lastHighlightableRow(for _: BookmarksOutlineView) -> Int?
}
extension BookmarksOutlineViewDataSource {
    func nextHighlightableRow(for outlineView: BookmarksOutlineView, after row: Int) -> Int? {
        nextHighlightableRow(inNextSection: false, for: outlineView, after: row)
    }
    func previousHighlightableRow(for outlineView: BookmarksOutlineView, before row: Int) -> Int? {
        previousHighlightableRow(inPreviousSection: false, for: outlineView, before: row)
    }
}

final class BookmarksOutlineView: NSOutlineView {

    private var highlightedRowView: RoundedSelectionRowView?
    private var highlightedCellView: BookmarkOutlineCellView?

    private var bookmarksDataSource: BookmarksOutlineViewDataSource? {
        dataSource as? BookmarksOutlineViewDataSource
    }

    @PublishedAfter var highlightedRow: Int? {
        didSet {
            defer {
                updateIsInKeyPopoverState()
            }
            highlightedRowView?.highlight = false
            highlightedCellView?.highlight = false
            guard let row = highlightedRow, row < numberOfRows else { return }
            if case .keyDown = NSApp.currentEvent?.type {
                scrollRowToVisible(row)
            }

            let item = item(atRow: row) as? BookmarkNode
            let rowView = rowView(atRow: row, makeIfNecessary: false) as? RoundedSelectionRowView
            rowView?.highlight = item?.canBeHighlighted ?? false
            highlightedRowView = rowView

            let cellView = self.view(atColumn: 0, row: row, makeIfNecessary: false) as? BookmarkOutlineCellView
            cellView?.highlight = item?.canBeHighlighted ?? false
            highlightedCellView = cellView
        }
    }

    /// popover displaying this Bookmarks Menu
    private var popover: NSPopover? {
        window?.contentViewController?.nextResponder as? NSPopover
    }

    /// return parent level Bookmarks Menu Outline View if this Bookmarks Menu is displayed as its submenu
    private var parentMenuOutlineView: Self? {
        if let window, // popover window
           let windowParent = window.parent, // parent popover window
           type(of: windowParent) == type(of: window) /* does window type match _NSPopoverWindow? */,
           let scrollView = windowParent.contentView?.subviews.first(where: { $0 is NSScrollView }) as? NSScrollView,
           let outlineView = scrollView.documentView as? Self {
            return outlineView
        }
        return nil
    }

    private var isInPopover: Bool {
        popover != nil
    }
    private var isInKeyPopover: Bool {
        guard highlightedRow != nil else { return false }
        // is there a child menu popover window owned by our window?
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

    // mark highlight with inactive color for non-key popover menu and with active color for key popover menu
    private func updateIsInKeyPopoverState() {
        guard isInPopover else {
            highlightedRowView?.isInKeyWindow = false
            highlightedCellView?.isInKeyWindow = false
            return
        }
        // when no highlighted row - our parent is the key popover
        guard highlightedRow != nil else {
            parentMenuOutlineView?.updateIsInKeyPopoverState()
            return
        }

        var isInKeyPopover = self.isInKeyPopover
        var outlineView: BookmarksOutlineView! = self
        while outlineView != nil {
            outlineView.highlightedRowView?.isInKeyWindow = isInKeyPopover
            outlineView.highlightedCellView?.isInKeyWindow = isInKeyPopover

            // if we‘re in the key popover all our parent popovers should not be key
            isInKeyPopover = false
            outlineView = outlineView.parentMenuOutlineView
        }
    }

    @objc private func popoverDidClose(_: Notification) {
        updateIsInKeyPopoverState()
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

        NotificationCenter.default.addObserver(self, selector: #selector(popoverDidClose), name: NSPopover.didCloseNotification, object: window?.contentViewController?.nextResponder)
    }

    override func didAdd(_ rowView: NSTableRowView, forRow row: Int) {
        super.didAdd(rowView, forRow: row)

        guard let rowView = rowView as? RoundedSelectionRowView,
              let cell = rowView.subviews.first as? BookmarkOutlineCellView else { return }

        let highlight = (row == highlightedRow)

        rowView.highlight = highlight
        cell.highlight = highlight

        if highlight {
            highlightedRowView = rowView
            highlightedCellView = cell

            updateIsInKeyPopoverState()
        }
    }

    override func mouseMoved(with event: NSEvent) {
        updateHighlightedRowUnderCursor()
    }

    override func mouseExited(with event: NSEvent) {
        let windowNumber = NSWindow.windowNumber(at: NSEvent.mouseLocation, belowWindowWithWindowNumber: 0)
        // don‘t reset highlight when mouse is exiting to a child popover
        guard let window, !(window.childWindows?.isEmpty ?? true),
              let mouseWindow = NSApp.window(withWindowNumber: windowNumber),
              type(of: mouseWindow) == type(of: window) /* _NSPopoverWindow */ else {
            highlightedRow = nil
            return
        }
    }

    override func keyDown(with event: NSEvent) {
        switch Int(event.keyCode) {
        case kVK_DownArrow, kVK_PageDown:
            onDownArrowPress(event)
        case kVK_UpArrow, kVK_PageUp:
            onUpArrowPress(event)
        case kVK_RightArrow:
            onRightArrowPress(event)
        case kVK_LeftArrow:
            onLeftArrowPress(event)
        default:
            super.keyDown(with: event)
        }
    }

    private func onDownArrowPress(_ event: NSEvent) {
        if let highlightedRow {
            // modify existing highlight
            if event.modifierFlags.contains(.option) || event.keyCode == kVK_PageDown,
               let lastRow = bookmarksDataSource?.lastHighlightableRow(for: self) {
                self.highlightedRow = lastRow
            } else if let nextRow = bookmarksDataSource?.nextHighlightableRow(inNextSection: event.modifierFlags.contains(.command), for: self, after: highlightedRow) {
                self.highlightedRow = nextRow
            }

        } else if let parentMenuOutlineView /* && highlightedRow == nil */ {
            // when no highlighted row in child menu popover: send event to parent menu to close the submenu and highlight next row
            parentMenuOutlineView.keyDown(with: event)
            return

        } else if event.modifierFlags.contains(.option) || event.keyCode == kVK_PageDown,
                  let lastRow = bookmarksDataSource?.lastHighlightableRow(for: self) {
            // highlight last row on Opt+Down
            self.highlightedRow = lastRow

        } else if let firstRow = bookmarksDataSource?.firstHighlightableRow(for: self) {
            // highlight first row on Down without existing highlight
            self.highlightedRow = firstRow
        }
    }

    private func onUpArrowPress(_ event: NSEvent) {
        if let highlightedRow {
            // modify existing highlight
            if event.modifierFlags.contains(.option) || event.keyCode == kVK_PageUp,
               let firstRow = bookmarksDataSource?.firstHighlightableRow(for: self) {
                self.highlightedRow = firstRow
            } else if let prevRow = bookmarksDataSource?.previousHighlightableRow(inPreviousSection: event.modifierFlags.contains(.command), for: self, before: highlightedRow) {
                self.highlightedRow = prevRow
            }

        } else if let parentMenuOutlineView /* && highlightedRow == nil */ {
            // when no highlighted row in child menu popover: send event to parent menu to close the submenu and highlight prev row
            parentMenuOutlineView.keyDown(with: event)
            return

        } else if event.modifierFlags.contains(.option) || event.keyCode == kVK_PageUp,
                  let firstRow = bookmarksDataSource?.firstHighlightableRow(for: self) {
            // highlight last row on Opt+Dp
            self.highlightedRow = firstRow

        } else if let lastRow = bookmarksDataSource?.lastHighlightableRow(for: self) {
            // highlight last row on Up without existing highlight
            self.highlightedRow = lastRow
        }
    }

    private func onRightArrowPress(_ event: NSEvent) {
        if parentMenuOutlineView != nil, highlightedRow == nil,
           let firstRow = bookmarksDataSource?.firstHighlightableRow(for: self) {
            // when we are in a submenu and no row highlighted: highlight first row on Right
            highlightedRow = firstRow

        } else if let highlightedRow, let item = self.item(atRow: highlightedRow),
                  isExpandable(item) {
            guard !isItemExpanded(item) else { return }
            // regular Outline View item expansion
            animator().expandItem(item)

        } else {
            // pass the key to the BookmarkListViewController to expand highlighted folder
            // or to delegate it to the Bookmarks Bar to open the next Bookmarks Menu
            nextResponder?.keyDown(with: event)
        }
    }

    private func onLeftArrowPress(_ event: NSEvent) {
        if parentMenuOutlineView != nil {
            // when we are in a submenu close the submenu on Left
            popover?.close()

        } else if let highlightedRow,
                  let item = self.item(atRow: highlightedRow),
                  isExpandable(item) {
            // regular Outline View item collapsing
            guard isItemExpanded(item) else { return }
            animator().collapseItem(item)

        } else {
            // pass the key to the BookmarkListViewController to delegate it to the Bookmarks Bar to open previous Bookmarks Menu
            nextResponder?.keyDown(with: event)
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
        guard let row = rowIfValid(forItem: item) else { return }
        self.highlightedRow = row
    }

    @discardableResult
    func highlightFirstItem() -> Bool {
        guard let prevRow = bookmarksDataSource?.firstHighlightableRow(for: self) else { return false }
        self.highlightedRow = prevRow
        return true
    }

    @discardableResult
    func highlightNextItem() -> Bool {
        guard let highlightedRow else { return highlightFirstItem() }
        guard let rowToHighlight = bookmarksDataSource?.nextHighlightableRow(for: self, after: highlightedRow) else { return false }
        self.highlightedRow = rowToHighlight
        return true
    }

    @discardableResult
    func highlightPreviousItem() -> Bool {
        guard let highlightedRow,
              let prevRow = bookmarksDataSource?.previousHighlightableRow(for: self, before: highlightedRow) else { return false }
        self.highlightedRow = prevRow
        return true
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
        } else if isInPopover {
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
