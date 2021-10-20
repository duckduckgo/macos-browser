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

    struct Constants {
        static let headerHeight: CGFloat = 222
        static let columns: Int = 5
        static let insets: CGSize = .zero
    }

    private var savedAttributes: [NSCollectionViewLayoutAttributes]?

    private var contentHeight: CGFloat {
        guard let collectionView = collectionView else { return 0 }
        let count = collectionView.numberOfItems(inSection: 0)
        guard count > 0 else { return 0 }

        let rows = count / Constants.columns + (count % Constants.columns > 0 ? 1 : 0)
        let itemHeight = (collectionView.delegate as? NSCollectionViewDelegateFlowLayout)?
            .collectionView?(collectionView, layout: self, sizeForItemAt: IndexPath(item: 0)).height
            ?? self.itemSize.height

        return Constants.headerHeight + itemHeight * CGFloat(rows) + self.minimumLineSpacing * CGFloat(rows - 1) + Constants.insets.height * 2
    }

    override var collectionViewContentSize: NSSize {
        NSSize(width: self.collectionView?.enclosingScrollView?.frame.size.width ?? 0,
               height: self.contentHeight)
    }

    override func layoutAttributesForElements(in rect: NSRect) -> [NSCollectionViewLayoutAttributes] {
        let largestRect = NSRect(x: 0, y: 0, width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        let allAttributes = super.layoutAttributesForElements(in: largestRect).map { ($0.copy() as? NSCollectionViewLayoutAttributes)! }
        guard !allAttributes.isEmpty,
              let scrollView = collectionView?.enclosingScrollView,
              let headerAttribute = allAttributes.first(where: { $0.representedElementKind == NSCollectionView.elementKindSectionHeader })
        else { return [] }

        let attributes = allAttributes.filter({ $0.representedElementKind != NSCollectionView.elementKindSectionHeader })
        guard !attributes.isEmpty else { return [] }

        let itemWidth = attributes[0].frame.size.width
        let actualColumns = min(Constants.columns, attributes.count)
        let spacing = actualColumns < Constants.columns
            ? minimumInteritemSpacing
        : min((scrollView.frame.size.width - (CGFloat(Constants.columns) * itemWidth + Constants.insets.width * 2))
              / CGFloat(Constants.columns - 1), minimumInteritemSpacing)
        let contentWidth = min(collectionViewContentSize.width, CGFloat(Constants.columns) * itemWidth + CGFloat(Constants.columns - 1) * spacing)

        let startX = (scrollView.frame.size.width - contentWidth) / 2
        let startY = max(Constants.insets.height,
                         (scrollView.frame.size.height / 2) - Constants.headerHeight)

        var headerMaxX = startX
        for (idx, attribute) in attributes.enumerated() {
            attribute.frame.origin.x = startX + (attribute.frame.height + spacing) * CGFloat(idx % Constants.columns)
            attribute.frame.origin.y = startY + Constants.headerHeight + (attribute.frame.height + minimumLineSpacing)
                                        * CGFloat(idx / Constants.columns)
            headerMaxX = max(headerMaxX, attribute.frame.maxX)
        }

        print(#function, startY)

        headerAttribute.frame.origin.x = startX
        headerAttribute.frame.origin.y = startY
        headerAttribute.frame.size.width = contentWidth
        headerAttribute.frame.size.height = Constants.headerHeight

        savedAttributes = allAttributes
        return allAttributes
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
