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
import os.log
import Carbon.HIToolbox

final class TabBarCollectionView: NSCollectionView {

    override func doCommand(by selector: Selector) {
        if let window = window {
            switch selector {
            case #selector(insertTab(_:)):
                window.selectKeyView(following: window.firstResponder as? NSView ?? self)
                return
            case #selector(insertBacktab(_:)):
                window.selectKeyView(preceding: window.firstResponder as? NSView ?? self)
                return
            default:
                break
            }
        }
        super.doCommand(by: selector)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        let nib = NSNib(nibNamed: "TabBarViewItem", bundle: nil)
        register(nib, forItemWithIdentifier: TabBarViewItem.identifier)

        // Register for the dropped object types we can accept.
        registerForDraggedTypes([.URL])
        // Enable dragging items within and into our CollectionView.
        setDraggingSourceOperationMask([.private], forLocal: true)
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

    var leftScrollButton: NSButton? {
        ((self.window as? MainWindow)?.contentViewController as? MainViewController)?.tabBarViewController.leftScrollButton
    }

    var newTabButton: NSButton? {
        (self.window as? MainWindow)?.newTabButton
    }

    private var itemsCache = [NSUserInterfaceItemIdentifier: [IndexPath: NSCollectionViewItem]]()

    override func makeItem(withIdentifier identifier: NSUserInterfaceItemIdentifier, for indexPath: IndexPath) -> NSCollectionViewItem {
        defer {
            itemsCache[identifier]?[indexPath] = nil
        }
        return itemsCache[identifier]?[indexPath] ?? super.makeItem(withIdentifier: identifier, for: indexPath)
    }

    override func accessibilityChildren() -> [Any]? {
        return self.allIndexPaths().compactMap { indexPath in
            self.item(at: indexPath)?.view ?? {
                guard let item = self.dataSource?.collectionView(self, itemForRepresentedObjectAt: indexPath) else { return nil }
                if let identifier = item.identifier {
                    itemsCache[identifier, default: [:]][indexPath] = item
                }
                item.view.setAccessibilityParent(self)
                return item.view
            }()

        } + [newTabButton].compactMap { $0 }
    }

    override func accessibilityVisibleChildren() -> [Any]? {
        accessibilityChildren()
    }

    override func accessibilityTabs() -> [Any]? {
        nil
    }

    override func accessibilityChildrenInNavigationOrder() -> [NSAccessibilityElementProtocol]? {
        accessibilityChildren()
    }

    override func selectItems(at indexPaths: Set<IndexPath>, scrollPosition: NSCollectionView.ScrollPosition) {
        if self.indexPathsForVisibleItems().isDisjoint(with: indexPaths),
           let indexPath = indexPaths.first {
            self.scroll(to: indexPath)
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
        let indexPath = IndexPath(item: index, section: 0)
        scroll(to: indexPath, completionHandler: completionHandler)
    }

    func scroll(to indexPath: IndexPath, completionHandler: ((Bool) -> Void)? = nil) {
        let rect = frameForItem(at: indexPath.item)
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
        let indexPaths = selectionIndexPaths ?? self.selectionIndexPaths
        visibleItems().forEach {
            ($0 as? TabBarViewItem)?.isLeftToSelected = false
        }

        for indexPath in indexPaths where indexPath.item > 0 {
            let leftToSelectionIndexPath = IndexPath(item: indexPath.item - 1)
            (item(at: leftToSelectionIndexPath) as? TabBarViewItem)?.isLeftToSelected = true
        }
// TODO: Use other flag // swiftlint:disable:this todo
        (item(at: self.numberOfItems(inSection: 0) - 1) as? TabBarViewItem)?.isLeftToSelected = true
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
