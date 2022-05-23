//
//  TabBarCollectionView.swift
//
//  Copyright © 2020 DuckDuckGo. All rights reserved.
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
import Combine
import os.log
import Carbon.HIToolbox

final class TabBarCollectionView: NSCollectionView {

    override func awakeFromNib() {
        super.awakeFromNib()
        
        let nib = NSNib(nibNamed: "TabBarViewItem", bundle: nil)
        register(nib, forItemWithIdentifier: TabBarViewItem.identifier)

        // Register for the dropped object types we can accept.
        registerForDraggedTypes([.URL])
        // Enable dragging items within and into our CollectionView.
        setDraggingSourceOperationMask([.private], forLocal: true)
    }

    private var firstResponderCancellable: AnyCancellable?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        firstResponderCancellable = window?.publisher(for: \.firstResponder).sink { [weak self] firstResponder in
            self?.firstResponderDidChange(firstResponder)
        }
    }

    override func accessibilityRole() -> NSAccessibility.Role? {
        .tabGroup
    }

    override func accessibilityFrame() -> NSRect {
        if let enclosingScrollView = self.enclosingScrollView,
           let newTabButton = newTabButton {
            return enclosingScrollView.accessibilityFrame().union(newTabButton.accessibilityFrame())
                .union(leftScrollButton?.accessibilityFrame() ?? newTabButton.accessibilityFrame())
        }

        return super.accessibilityFrame()
    }

    private var tabBarViewController: TabBarViewController? {
        delegate as? TabBarViewController
    }

    private var leftScrollButton: NSButton? {
        tabBarViewController?.leftScrollButton
    }

    private var newTabButton: NSButton? {
        tabBarViewController?.addNewTabButton
    }

    private var itemsCache = [NSUserInterfaceItemIdentifier: [IndexPath: NSCollectionViewItem]]()

    override func makeItem(withIdentifier identifier: NSUserInterfaceItemIdentifier, for indexPath: IndexPath) -> NSCollectionViewItem {
        defer {
            itemsCache[identifier]?[indexPath] = nil
        }
        return itemsCache[identifier]?[indexPath] ?? super.makeItem(withIdentifier: identifier, for: indexPath)
    }

    private func getAccessibilityTabs() -> [NSAccessibilityElementProtocol] {
        self.allIndexPaths().compactMap { indexPath in
            self.item(at: indexPath)?.view ?? {
                guard let item = self.dataSource?.collectionView(self, itemForRepresentedObjectAt: indexPath) else { return nil }
                if let identifier = item.identifier {
                    itemsCache[identifier, default: [:]][indexPath] = item
                }
                item.view.setAccessibilityParent(self)
                return item.view
            }()

        }
    }

    private func getAccessibilityChildren() -> [NSAccessibilityElementProtocol] {
        var children = getAccessibilityTabs()
        if let newTabButton = newTabButton {
            children.append(newTabButton)
        }
        return children
    }

    override func accessibilityChildren() -> [Any]? {
        getAccessibilityChildren()
    }

    override func accessibilityVisibleChildren() -> [Any]? {
        getAccessibilityChildren()
    }

    override func accessibilityChildrenInNavigationOrder() -> [NSAccessibilityElementProtocol]? {
        getAccessibilityChildren()
    }

    override func accessibilityTabs() -> [Any]? {
        getAccessibilityChildren()
    }

    override func doCommand(by selector: Selector) {
        guard let window = window else { return }
        switch selector {
        case #selector(insertTab(_:)):
            window.selectKeyView(following: window.firstResponder as? NSView ?? self)

        case #selector(moveRight(_:)):
            focusNextItem()

        case #selector(moveWordRight(_:)):
            focusTabsPage(+1)

        case #selector(moveDown(_:)),
             #selector(moveToRightEndOfLine(_:)),
             #selector(moveToEndOfDocument(_:)),
             #selector(moveToEndOfParagraph(_:)):
            focusLastItem()

        case #selector(insertBacktab(_:)):
            window.selectKeyView(preceding: window.firstResponder as? NSView ?? self)

        case #selector(moveLeft(_:)):
            focusPreviousItem()

        case #selector(moveWordLeft(_:)):
            focusTabsPage(-1)

        case #selector(moveUp(_:)),
             #selector(moveToLeftEndOfLine(_:)),
             #selector(moveToBeginningOfDocument(_:)),
             #selector(moveToBeginningOfParagraph(_:)):
            focusFirstItem()

        default:
            super.doCommand(by: selector)
        }
    }

    private enum TabBarFocusState {
        case scrollingTo
        case focusInside
    }
    private var focusState: TabBarFocusState?

    private func firstResponderDidChange(_ firstResponder: Any?) {
        let firstResponder = firstResponder as? NSView
        let isFocusInside = self.enclosingScrollView.map { scrollView in firstResponder?.isDescendant(of: scrollView) ?? false } ?? false
        switch (focusState, isFocusInside) {
        case (.scrollingTo, true):
            self.focusState = .focusInside
        case (.scrollingTo, false), (.none, false):
            break
        case (.focusInside, true), (.none, true):
            defer {
                self.focusState = .focusInside
            }
            guard let indexPath = indexPathForItemWithFocusedView(),
                  !self.isItemVisible(at: indexPath.item)
            else {
                break
            }

            self.scroll(to: indexPath.item)

        case (.focusInside, false):
            scrollToSelected()
            self.focusState = .none
        }
    }

    private func indexPathForItemWithFocusedView() -> IndexPath? {
        guard let focusedView = window?.firstResponder as? NSView,
              let scrollView = self.enclosingScrollView,
              focusedView.isDescendant(of: scrollView)
        else { return nil }

        if let item = window?.firstResponder?.nextResponder as? TabBarViewItem {
            return self.indexPath(for: item)
        }

        let point = self.convert(focusedView.bounds.center, from: focusedView)
        return self.indexPathForItem(at: point)
    }

    func focusNextItem() {
        guard let indexPath = indexPathForItemWithFocusedView(),
              self.numberOfItems(inSection: 0) > indexPath.item + 1
        else {
            __NSBeep()
            return
        }

        focusItem(at: IndexPath(item: indexPath.item + 1, section: 0))
    }

    func focusPreviousItem() {
        guard let indexPath = indexPathForItemWithFocusedView(),
              indexPath.item > 0
        else {
            __NSBeep()
            return
        }

        focusItem(at: IndexPath(item: indexPath.item - 1, section: 0))
    }

    func focusTabsPage(_ n: Int) {
        guard let indexPath = indexPathForItemWithFocusedView(),
              let clipView = enclosingScrollView?.contentView
        else {
            __NSBeep()
            return
        }

        let leftmostPoint = self.convert(NSPoint(x: clipView.visibleRect.minX,
                                                 y: clipView.visibleRect.midY),
                                         from: clipView)
        let rightmostPoint = self.convert(NSPoint(x: clipView.visibleRect.maxX,
                                                  y: clipView.visibleRect.midY),
                                          from: clipView)

        // calculate next/previous scroll "page" frame
        let lastItem = self.numberOfItems(inSection: 0) - 1
        let firstVisibleIndexPath = self.indexPathForItem(at: leftmostPoint) ?? IndexPath(item: 0, section: 0)
        let lastVisibleIndexPath = self.indexPathForItem(at: rightmostPoint) ?? IndexPath(item: lastItem, section: 0)

        let distance = lastVisibleIndexPath.item - firstVisibleIndexPath.item
        let indexPathToFocus  = n > 0 ? lastVisibleIndexPath : firstVisibleIndexPath
        let scrollTo = min(max(0, indexPath.item + distance * n * 2), lastItem)

        self.focusState = .scrollingTo
        scroll(to: scrollTo) { [weak self] _ in
            self?.focusItem(at: indexPathToFocus)
        }
    }

    func focusFirstItem() {
        focusItem(at: IndexPath(item: 0, section: 0))
    }

    func focusLastItem() {
        focusItem(at: IndexPath(item: self.numberOfItems(inSection: 0) - 1, section: 0))
    }

    func focusItem(at indexPath: IndexPath) {
        if self.isItemVisible(at: indexPath.item) {
            self.item(at: indexPath)?.view.makeMeFirstResponder()
        } else {
            self.focusState = .scrollingTo
            self.scroll(to: indexPath.item) { [weak self] _ in
                self?.item(at: indexPath)?.view.makeMeFirstResponder()
            }
        }
    }

    func isItemVisible(at index: Int) -> Bool {
        guard let clipView = enclosingScrollView?.contentView else { return false }
        let frame = frameForItem(at: index)
        return clipView.documentVisibleRect.contains(frame)
    }

    override func selectItems(at indexPaths: Set<IndexPath>, scrollPosition: NSCollectionView.ScrollPosition) {
        guard let indexPath = indexPaths.first else { return }
        if !self.isItemVisible(at: indexPath.item) {
            self.scroll(to: indexPath.item)
        }
        super.selectItems(at: indexPaths, scrollPosition: scrollPosition)

        updateItemsLeftToSelectedItems(indexPaths)
    }

    func clearSelection(animated: Bool = false) {
        if animated {
            animator().deselectItems(at: selectionIndexPaths)
        } else {
            deselectItems(at: selectionIndexPaths)
        }
    }

    func scrollToSelected() {
        guard selectionIndexPaths.count == 1, let indexPath = selectionIndexPaths.first else {
            os_log("TabBarCollectionView: More than 1 item or no item highlighted", type: .error)
            return
        }
        scroll(to: indexPath.item)
    }

    func scroll(to index: Int, completionHandler: ((Bool) -> Void)? = nil) {
        let rect = frameForItem(at: index)
        animator().performBatchUpdates({
            animator().scrollToVisible(rect)
        }, completionHandler: completionHandler)
    }

    func scrollToEnd(completionHandler: ((Bool) -> Void)? = nil) {
        animator().performBatchUpdates({
            animator().scroll(CGPoint(x: self.bounds.size.width, y: 0))
        }, completionHandler: completionHandler)
    }

    func scrollToBeginning(completionHandler: ((Bool) -> Void)? = nil) {
        animator().performBatchUpdates({
            animator().scroll(CGPoint(x: 0, y: 0))
        }, completionHandler: completionHandler)
    }

    func invalidateLayout() {
        NSAnimationContext.current.duration = 1/3
        collectionViewLayout?.invalidateLayout()
    }

    func updateItemsLeftToSelectedItems(_ selectionIndexPaths: Set<IndexPath>? = nil) {
        let selectedIndex = (selectionIndexPaths ?? self.selectionIndexPaths)?.first?.item
        let lastIndexPath = IndexPath(item: self.numberOfItems(inSection: 0) - 1, section: 0)
        for indexPath in indexPathsForVisibleItems() {
            guard let item = item(at: indexPath) as? TabBarViewItem else { continue }

            item.isSeparatorHidden = indexPath.item + 1 == selectedIndex // left to selected
                || (tabBarViewController?.tabMode == .overflow && indexPath == lastIndexPath)
        }
    }

}

extension NSCollectionView {

    var clipView: NSClipView? {
        return enclosingScrollView?.contentView
    }

    var isAtEndScrollPosition: Bool {
        guard let clipView = clipView else {
            os_log("TabBarCollectionView: Clip view is nil", type: .error)
            return false
        }

        return clipView.bounds.origin.x + clipView.bounds.size.width >= bounds.size.width
    }

    var isAtStartScrollPosition: Bool {
        guard let clipView = clipView else {
            os_log("TabBarCollectionView: Clip view is nil", type: .error)
            return false
        }

        return clipView.bounds.origin.x <= 0
    }

}
