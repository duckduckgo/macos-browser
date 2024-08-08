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
import Combine

final class BookmarksOutlineView: NSOutlineView {

    private var highlightedRowView: RoundedSelectionRowView?
    private var highlightedCellView: BookmarkOutlineCellView?

    @PublishedAfter var highlightedRow: Int? {
        didSet {
            highlightedRowView?.highlight = false
            highlightedCellView?.highlight = false
            guard let row = highlightedRow else { return }
            if case .keyDown = NSApp.currentEvent?.type {
                scrollRowToVisible(row)
            }

            let item = item(atRow: row) as? BookmarkNode

            let rowView = rowView(atRow: row, makeIfNecessary: false) as? RoundedSelectionRowView
            rowView?.isInKeyWindow = true
            rowView?.highlight = item?.canBeHighlighted ?? false
            highlightedRowView = rowView

            let cellView = self.view(atColumn: 0, row: row, makeIfNecessary: false) as? BookmarkOutlineCellView
            cellView?.isInKeyWindow = true
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

    override var clickedRow: Int {
        let clickedRow = super.clickedRow
        // on Enter/Space key down: click event is sent to the OutlineView target with highlightedRow
        if [-1, NSNotFound].contains(clickedRow), let highlightedRow,
           NSApp.currentEvent?.type == .keyDown {

            return highlightedRow
        }
        return clickedRow
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
        let point = mouseLocationInsideBounds()
        let row = point.map { self.row(at: NSPoint(x: self.bounds.midX, y: $0.y)) } ?? -1
        guard row >= 0, row < NSNotFound else {
            // TODO: don‘t highlight but mark as non-active when mouse exit to
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

    override func keyDown(with event: NSEvent) {
        switch Int(event.keyCode) {
        case kVK_DownArrow:
            if let highlightedRow {
                guard highlightedRow < numberOfRows - 1 else { return }
                if event.modifierFlags.contains(.command) || event.modifierFlags.contains(.option) {
                    self.highlightedRow = numberOfRows - 1
                } else {
                    self.highlightedRow = highlightedRow + 1
                }

            } else if numberOfRows > 0 /* && highlightedRow == nil */ {
                if let window, let windowParent = window.parent,
                   type(of: windowParent) == type(of: window) /* _NSPopoverWindow */,
                    let scrollView = windowParent.contentView?.subviews.first(where: { $0 is NSScrollView }) as? NSScrollView,
                    let outlineView = scrollView.documentView as? Self {

                    // when no highlighted row in child menu popover: send event to parent menu
                    outlineView.keyDown(with: event)

                } else if event.modifierFlags.contains(.option) {
                    self.highlightedRow = numberOfRows - 1
                } else {
                    self.highlightedRow = 0
                }
            }
        case kVK_UpArrow: // TODO: pgUp/Down, modifiers
            if let highlightedRow {
                guard highlightedRow > 0 else { return }
                if event.modifierFlags.contains(.command) || event.modifierFlags.contains(.option) {
                    self.highlightedRow = 0
                } else {
                    self.highlightedRow = highlightedRow - 1
                }

            } else if numberOfRows > 0 /* && highlightedRow == nil */ {
                if let window, let windowParent = window.parent,
                   type(of: windowParent) == type(of: window) /* _NSPopoverWindow */,
                   let scrollView = windowParent.contentView?.subviews.first(where: { $0 is NSScrollView }) as? NSScrollView,
                   let outlineView = scrollView.documentView as? Self {

                    // when no highlighted row in child menu popover: send event to parent menu
                    outlineView.keyDown(with: event)

                } else if event.modifierFlags.contains(.option) {
                    self.highlightedRow = 0
                } else {
                    self.highlightedRow = numberOfRows - 1
                }
            }
        case kVK_RightArrow:
            if let window, let windowParent = window.parent,
               type(of: windowParent) == type(of: window) /* _NSPopoverWindow */,
               let scrollView = windowParent.contentView?.subviews.first(where: { $0 is NSScrollView }) as? NSScrollView,
               let outlineView = scrollView.documentView as? Self {
                outlineView.highlightedRowView?.isInKeyWindow = false
                outlineView.highlightedCellView?.isInKeyWindow = false
                if highlightedRow == nil, numberOfRows > 0 {
                    highlightedRow = 0
                    break
                }
            }
            if let highlightedRow, let item = self.item(atRow: highlightedRow),
               isExpandable(item) {
                if !isItemExpanded(item) {
                    animator().expandItem(item)
                }
            } else if numberOfRows > 0 {
                self.highlightedRow = highlightedRow
            }

            // TODO: when in root: open next menu, left arrow: prev menu
        case kVK_LeftArrow:
            if let window, let windowParent = window.parent,
               type(of: windowParent) == type(of: window) /* _NSPopoverWindow */,
               let scrollView = windowParent.contentView?.subviews.first(where: { $0 is NSScrollView }) as? NSScrollView,
               let outlineView = scrollView.documentView as? Self,
               let popover = window.contentViewController?.nextResponder as? NSPopover {

                // close child menu
                popover.close()
                outlineView.highlightedRowView?.isInKeyWindow = true
                outlineView.highlightedCellView?.isInKeyWindow = true

            } else if let highlightedRow,
                      let item = self.item(atRow: highlightedRow),
                      isExpandable(item), isItemExpanded(item) {
                animator().collapseItem(item)
            } else {
//                super.keyDown(with: event)
            }

        case kVK_Return, kVK_ANSI_KeypadEnter, kVK_Space:
            if highlightedRow != nil {
                guard let action else {
                    assertionFailure("BookmarksOutlineView.action not set")
                    return
                }
                // select highlighted item
                NSApp.sendAction(action, to: target, from: self)

            } else if let window, let windowParent = window.parent,
                      type(of: windowParent) == type(of: window) /* _NSPopoverWindow */,
                      let scrollView = windowParent.contentView?.subviews.first(where: { $0 is NSScrollView }) as? NSScrollView,
                      let outlineView = scrollView.documentView as? Self,
                      numberOfRows > 0 {

                // when in child menu popover without selection: highlight first row
                highlightedRow = 0

                outlineView.highlightedRowView?.isInKeyWindow = false
                outlineView.highlightedCellView?.isInKeyWindow = false
            }

        case kVK_Escape:
            var window = window
            while let windowParent = window?.parent,
                  type(of: windowParent) == type(of: window!) {
                window = windowParent
            }
            // close root popover on Esc
            if let popover = window?.contentViewController?.nextResponder as? NSPopover {
                popover.close()
            }

        default:
            super.keyDown(with: event)
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

}
