//
//  KeyboardControllableCollectionView.swift
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

final class KeyboardControllableCollectionView: NSCollectionView {

    @IBInspectable var shouldSelectOnFocus: Bool = false
    @IBInspectable var shouldSelectOnMouseDown: Bool = false
    private var isSelectionImplicit = false
    private var selectionIndexesCancellable: AnyCancellable?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        guard window != nil else {
            selectionIndexesCancellable = nil
            return
        }
        selectionIndexesCancellable = self.publisher(for: \.selectionIndexPaths).sink { [weak self] _ in
            self?.isSelectionImplicit = false
        }
    }

    override func becomeFirstResponder() -> Bool {
        if shouldSelectOnFocus && selectionIndexPaths.isEmpty && NSApp.currentEvent?.type == .keyDown {
            self.selectFirst()
            isSelectionImplicit = true
        }
        return super.becomeFirstResponder()
    }

    override func resignFirstResponder() -> Bool {
        if isSelectionImplicit {
            self.selectionIndexPaths = []
        }
        return super.resignFirstResponder()
    }

    func allIndexPaths() -> [IndexPath] {
        (0..<numberOfSections).reduce(into: [IndexPath]()) { result, section in
            result.append(contentsOf: (0..<numberOfItems(inSection: section))
                .map { IndexPath(item: $0, section: section) })
        }
    }

    @discardableResult
    func select(_ indexPath: IndexPath, extendingSelection: Bool = false, scrollPosition: NSCollectionView.ScrollPosition) -> Bool {
        return select([indexPath], extendingSelection: extendingSelection, scrollPosition: scrollPosition)
    }

    @discardableResult
    func select(_ indexPaths: Set<IndexPath>, extendingSelection: Bool = false, scrollPosition: NSCollectionView.ScrollPosition) -> Bool {
        let indexPaths = self.delegate?.collectionView?(self, shouldSelectItemsAt: indexPaths) ?? indexPaths
        if extendingSelection {
            selectItems(at: indexPaths, scrollPosition: scrollPosition)
        } else if !indexPaths.isEmpty {
            selectionIndexPaths = indexPaths
            scrollToItems(at: indexPaths, scrollPosition: scrollPosition)
        }
        return !indexPaths.isEmpty
    }

    override func keyDown(with event: NSEvent) {
        switch Int(event.keyCode) {
        case kVK_DownArrow:
            if NSApp.isCommandPressed { fallthrough }
            selectNext(extend: NSApp.isShiftPressed)

        case kVK_End:
            if NSApp.isShiftPressed {
                extendSelection(upTo: IndexPath(item: self.numberOfItems(inSection: self.numberOfSections - 1) - 1,
                                                section: self.numberOfSections - 1))
                return
            }
            selectLast()

        case kVK_UpArrow:
            if NSApp.isCommandPressed { fallthrough }
            selectPrevious(extend: NSApp.isShiftPressed)

        case kVK_Home:
            if NSApp.isShiftPressed {
                self.extendSelection(upTo: IndexPath(item: 0, section: 0))
                return
            }
            selectFirst()

        case kVK_Space:
            NSApp.sendAction(#selector(NSCell.performClick(_:)), to: nil, from: self)

        default:
            super.keyDown(with: event)
        }
    }

    func nextIndexPath(after indexPath: IndexPath) -> IndexPath? {
        return allIndexPaths().first(where: { $0 > indexPath })
    }

    func selectNext(extend: Bool = false) {
        let lastSelected = selectionIndexPaths.max() ?? IndexPath(item: -1, section: -1)
        guard let nextIndexPath = nextIndexPath(after: lastSelected) ?? allIndexPaths().last else { return }

        if select(nextIndexPath, extendingSelection: extend, scrollPosition: .nearestVerticalEdge) == false && !extend {
            select(lastSelected, scrollPosition: .nearestVerticalEdge)
        }
    }

    func selectLast() {
        var allIndexPaths = self.allIndexPaths()
        while !allIndexPaths.isEmpty {
            if self.select(allIndexPaths.removeLast(), scrollPosition: .bottom) {
                return
            }
        }
    }

    func extendSelection(upTo indexPath: IndexPath) {
        let selectionIndexPaths = self.selectionIndexPaths
        guard let minSelected = selectionIndexPaths.min() else {
            self.select(indexPath, scrollPosition: .nearestVerticalEdge)
            return
        }

        let allIndexPaths = allIndexPaths()
        let indexPaths: Set<IndexPath>
        if indexPath < minSelected {
            indexPaths = Set(allIndexPaths.filter { $0 >= indexPath && $0 < minSelected })
        } else if let maxSelected = selectionIndexPaths.max() {
            if indexPath > maxSelected {
                indexPaths = Set(allIndexPaths.filter { $0 > maxSelected && $0 <= indexPath })
            } else {
                indexPaths = Set(allIndexPaths.filter { $0 >= indexPath && $0 < maxSelected })
            }
        } else {
            indexPaths = [indexPath]
        }

        select(indexPaths, extendingSelection: true, scrollPosition: .bottom)
    }

    func previousIndexPath(before indexPath: IndexPath) -> IndexPath? {
        return allIndexPaths().last(where: { $0 < indexPath })
    }

    func selectPrevious(extend: Bool = false) {
        let firstSelected = selectionIndexPaths.min() ?? IndexPath(item: Int.max, section: Int.max)
        guard let prevIndexPath = previousIndexPath(before: firstSelected) ?? allIndexPaths().first else { return }

        if select(prevIndexPath, extendingSelection: extend, scrollPosition: .nearestVerticalEdge) == false && !extend {
            select(firstSelected, scrollPosition: .nearestVerticalEdge)
        }
    }

    func selectFirst() {
        var allIndexPaths = self.allIndexPaths()
        while !allIndexPaths.isEmpty {
            if self.select(allIndexPaths.removeFirst(), scrollPosition: .top) {
                return
            }
        }
    }

    override func mouseDown(with event: NSEvent) {
        if shouldSelectOnMouseDown,
           !NSApp.isCommandPressed || NSApp.isShiftPressed,
           let point = self.mouseLocationInsideBounds(event.locationInWindow) {
            if !self.isFirstResponder {
                self.makeMeFirstResponder()
            }

            guard let indexPath = self.indexPathForItem(at: point) else { return }

            if NSApp.isShiftPressed {
                self.extendSelection(upTo: indexPath)
            } else {
                self.select(indexPath, extendingSelection: NSApp.isShiftPressed, scrollPosition: .nearestVerticalEdge)
            }

            return
        }
        super.mouseDown(with: event)
    }

}
