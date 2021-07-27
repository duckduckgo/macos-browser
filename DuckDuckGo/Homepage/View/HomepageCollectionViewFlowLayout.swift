//
//  HomepageCollectionViewFlowLayout.swift
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

import Cocoa

final class HomepageCollectionViewFlowLayout: NSCollectionViewFlowLayout {

    @IBInspectable var columns: Int = 1
    @IBInspectable var insets: CGSize = .zero
    @IBInspectable var verticalShift: CGFloat = 0
    private var savedAttributes: [NSCollectionViewLayoutAttributes]?

    private var contentHeight: CGFloat {
        guard let collectionView = collectionView else { return 0 }
        let count = collectionView.numberOfItems(inSection: 0)
        guard count > 0 else { return 0 }

        let rows = count / columns + (count % columns > 0 ? 1 : 0)
        let itemHeight = (collectionView.delegate as? NSCollectionViewDelegateFlowLayout)?
            .collectionView?(collectionView, layout: self, sizeForItemAt: IndexPath(item: 0)).height
            ?? self.itemSize.height

        return itemHeight * CGFloat(rows) + self.minimumLineSpacing * CGFloat(rows - 1) + insets.height * 2
    }

    override var collectionViewContentSize: NSSize {
        NSSize(width: self.collectionView?.enclosingScrollView?.frame.size.width ?? 0,
               height: self.contentHeight)
    }

    override func layoutAttributesForElements(in rect: NSRect) -> [NSCollectionViewLayoutAttributes] {
        let largestRect = NSRect(x: 0, y: 0, width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        let attributes = super.layoutAttributesForElements(in: largestRect).map { ($0.copy() as? NSCollectionViewLayoutAttributes)! }
        guard !attributes.isEmpty,
              let scrollView = collectionView?.enclosingScrollView
        else { return [] }

        let itemWidth = attributes[0].frame.size.width
        let actualColumns = min(columns, attributes.count)
        let spacing = actualColumns < columns
            ? minimumInteritemSpacing
            : min((scrollView.frame.size.width - (CGFloat(columns) * itemWidth + insets.width * 2))
                  / CGFloat(columns - 1), minimumInteritemSpacing)
        let contentWidth = CGFloat(columns) * itemWidth + CGFloat(columns - 1) * spacing

        let startX = (scrollView.frame.size.width - contentWidth) / 2
        let startY = max(insets.height,
                        (scrollView.frame.size.height - contentHeight) / 2 + insets.height + verticalShift)

        for (idx, attribute) in attributes.enumerated() {
            attribute.frame.origin.x = startX + (attribute.frame.height + spacing) * CGFloat(idx % columns)
            attribute.frame.origin.y = startY + (attribute.frame.height + minimumLineSpacing) * CGFloat(idx / columns)
        }

        savedAttributes = attributes
        return attributes
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: NSRect) -> Bool {
        true
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> NSCollectionViewLayoutAttributes? {
        guard let savedAttributes = savedAttributes,
              savedAttributes.indices.contains(indexPath.item)
        else { return nil }
        return savedAttributes[indexPath.item]
    }

}
