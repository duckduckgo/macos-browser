//
//  KeyboardControllableTableView.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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
import Carbon.HIToolbox
import Combine

final class KeyboardControllableTableView: NSTableView {

    @IBInspectable var levelUpAction: String?
    @IBInspectable var shouldDeselectOnFirstResponderInsideView: Bool = false

    private var isSelectionImplicit = false
    private var lastSelectedRow: Int?
    private var firstResponderCancellable: AnyCancellable?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        self.firstResponderCancellable = self.window?.publisher(for: \.firstResponder).sink { [weak self] responder in
            if responder === self {
                self?.didBecomeFirstResponder()
            } else {
                self?.didResignFirstResponder(newResponder: responder)
            }
        }
    }

    private func didBecomeFirstResponder() {
        if selectedRowIndexes.isEmpty,
           self.numberOfRows > 0,
           [.keyDown, .systemDefined].contains(NSApp.currentEvent?.type),
           // don‘t select row when previous responder‘s window is another window
           // i.e. the control becomes first responder on window appear
           (self.window?.firstResponder as? NSView)?.window === self.window {

            if let lastSelectedRow = lastSelectedRow,
               self.delegate?.tableView?(self, shouldSelectRow: lastSelectedRow) == false {
                self.lastSelectedRow = nil
            }
            if self.delegate?.tableView?(self, shouldSelectRow: lastSelectedRow ?? 0) != false {
                self.selectRowIndexes(IndexSet(integer: lastSelectedRow ?? 0), byExtendingSelection: false)
                self.isSelectionImplicit = lastSelectedRow == nil
            }
        }
    }

    private func didResignFirstResponder(newResponder: NSResponder?) {
        if !self.selectedRowIndexes.isEmpty,
           // Deselect implicit selection
           // Or deselect when first responder is a link inside the table
           isSelectionImplicit
            || (shouldDeselectOnFirstResponderInsideView
                && (newResponder as? NSView)?.isDescendant(of: self) == true) {
            self.lastSelectedRow = self.selectedRow
            self.deselectAll(nil)
        }
        self.isSelectionImplicit = false
   }

    override func selectRowIndexes(_ indexes: IndexSet, byExtendingSelection extend: Bool) {
        super.selectRowIndexes(indexes, byExtendingSelection: extend)
        self.isSelectionImplicit = false
    }

    override func keyDown(with event: NSEvent) {
        switch Int(event.keyCode) {
        case kVK_UpArrow where NSApp.isCommandPressed:
            guard let levelUpAction = levelUpAction else { break }
            NSApp.sendAction(NSSelectorFromString(levelUpAction), to: self.target, from: send)
            return

        case kVK_DownArrow where NSApp.isCommandPressed:
            guard let doubleAction = self.doubleAction,
                  self.selectedRow >= 0,
                  let selectedCell = self.view(atColumn: 0, row: selectedRow, makeIfNecessary: false)
            else { break }

            NSApp.sendAction(doubleAction, to: self.target, from: selectedCell)
            return
            
        default:
            break
        }
        super.keyDown(with: event)
    }

}
