//
//  ItemCachingCollectionView.swift
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

final class ItemCachingCollectionView: NSCollectionView {

    private struct CollectionViewItemCacheIdentifier: Hashable {
        let identifier: NSUserInterfaceItemIdentifier
        let indexPath: IndexPath
    }

    private var collectionViewItemCache = [CollectionViewItemCacheIdentifier: NSCollectionViewItem]()

    /// try to reuse an item at the same IndexPath that is requested to keep the same view position
    /// when an item with another IndexPath is used, the Bookmarks Menu popover changes its placement as it‘s tied to the original view
    /// or items hovered state is blinking under mouse cursor when bookmarks are reloaded
    override func makeItem(withIdentifier identifier: NSUserInterfaceItemIdentifier, for indexPath: IndexPath) -> NSCollectionViewItem {
        if let item = collectionViewItemCache.removeValue(forKey: .init(identifier: identifier, indexPath: indexPath)) {
            return item
        }

        repeat {
            let item = super.makeItem(withIdentifier: identifier, for: indexPath)
            // if the returned item is being reused but doesn‘t match our IndexPath – cache it for the future use
            if let itemIndexPath = item.indexPath, itemIndexPath != indexPath {
                // cache items for other IndexPaths
                collectionViewItemCache[.init(identifier: identifier, indexPath: itemIndexPath)] = item
            } else /* if item.indexPath == nil || item.indexPath == indexPath */ {
                item.indexPath = indexPath
                return item // that‘s either our item or a newly created one
            }
        } while true
    }

    override func layout() {
        super.layout()
        // update visible items index paths
        for indexPath in indexPathsForVisibleItems() {
            guard let item = self.item(at: indexPath.item) else {
                assertionFailure("Could not get item identifier or IndexPath")
                continue
            }
            if item.indexPath != indexPath {
                item.indexPath = indexPath
            }
        }

        // reused items may stay in the Collection View hierarchy creating a mess after the number of item reduces.
        // here we remove all the items that remained unused during update.
        for item  in collectionViewItemCache.values {
            item.view.removeFromSuperview()
        }
        collectionViewItemCache.removeAll(keepingCapacity: true)
    }

}

fileprivate extension NSCollectionViewItem {

    // last known IndexPath at which the NSCollectionViewItem was used
    private static let indexPathKey = UnsafeRawPointer(bitPattern: "indexPathKey".hashValue)!
    var indexPath: IndexPath? {
        get {
            objc_getAssociatedObject(self, Self.indexPathKey) as? IndexPath
        }
        set {
            objc_setAssociatedObject(self, Self.indexPathKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }

}
