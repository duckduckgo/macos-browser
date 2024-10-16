//
//  BookmarksBarCenterAlignedLayout.swift
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

extension NSCollectionView {
    static let interItemGapIndicatorIdentifier = "NSCollectionElementKindInterItemGapIndicator"
}

extension NSCollectionLayoutGroup {

    static func align(cellSizes: [CGSize], interItemSpacing: CGFloat, centered: Bool) -> NSCollectionLayoutGroup {
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(28))

        return custom(layoutSize: groupSize) { environment in
            let verticalPosition: CGFloat = environment.container.contentInsets.top
            let totalWidth = cellSizes.map(\.width).reduce(0) { $0 == 0 ? $1 : $0 + interItemSpacing + $1 }
            let maxItemHeight = cellSizes.map(\.height).max() ?? 0

            var items: [NSCollectionLayoutGroupCustomItem] = []
            var horizontalPosition: CGFloat

            if centered {
                horizontalPosition = (environment.container.effectiveContentSize.width - totalWidth) / 2 + environment.container.contentInsets.leading
            } else {
                horizontalPosition = interItemSpacing
            }

            let rowItems: [NSCollectionLayoutGroupCustomItem] = cellSizes.map { size in
                let origin = CGPoint(x: ceil(horizontalPosition), y: verticalPosition + (maxItemHeight - size.height) / 2)
                let itemFrame = CGRect(origin: origin, size: size)
                horizontalPosition += (size.width + interItemSpacing)

                return NSCollectionLayoutGroupCustomItem(frame: itemFrame)
            }

            items.append(contentsOf: rowItems)

            return items
        }
    }
}

final class BookmarksBarCenterAlignedLayout: NSCollectionViewCompositionalLayout {

    private static let interItemGapWidth: CGFloat = 2.0

    private var lastKnownInterItemGapIndicatorLayoutAttributes: NSCollectionViewLayoutAttributes?

    override func layoutAttributesForInterItemGap(before indexPath: IndexPath) -> NSCollectionViewLayoutAttributes? {
        let result = super.layoutAttributesForInterItemGap(before: indexPath)
        if let result, result.frame.width < Self.interItemGapWidth {
            result.frame.origin.x -= (Self.interItemGapWidth - result.frame.width) * 0.5
            result.frame.size.width = Self.interItemGapWidth
        }
        return result
    }

    override func layoutAttributesForDropTarget(at pointInCollectionView: NSPoint) -> NSCollectionViewLayoutAttributes? {
        var result = super.layoutAttributesForDropTarget(at: pointInCollectionView)
        if result == nil, let gapAttributes = lastKnownInterItemGapIndicatorLayoutAttributes,
           gapAttributes.frame.contains(pointInCollectionView) {
            result = gapAttributes
        }
        if let result, result.representedElementKind == NSCollectionView.interItemGapIndicatorIdentifier {
            if result.frame.width < Self.interItemGapWidth {
                result.frame.origin.x -= (Self.interItemGapWidth - result.frame.width) * 0.5
                result.frame.size.width = Self.interItemGapWidth
            }
            lastKnownInterItemGapIndicatorLayoutAttributes = result
        }
        return result
    }

}
