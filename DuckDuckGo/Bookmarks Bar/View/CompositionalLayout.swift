//
//  CompositionalLayout.swift
//  BookmarksBar
//
//  Created by Sam Symons on 2022-06-25.
//

import AppKit

extension NSCollectionLayoutGroup {

    static func horizontallyCentered(cellSizes: [CGSize], interItemSpacing: CGFloat = 8, centered: Bool = true) -> NSCollectionLayoutGroup {
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(32))
        
        return custom(layoutSize: groupSize) { environment in
            let verticalPosition: CGFloat = environment.container.contentInsets.top

            var items: [NSCollectionLayoutGroupCustomItem] = []
            var rowSizes: [CGSize] = []
            
            func totalWidth() -> CGFloat {
                rowSizes.map(\.width).reduce(0) {
                    $0 == 0 ? $1 : $0 + interItemSpacing + $1
                }
            }
            
            func addRowItems() {
                var xPos: CGFloat
                
                if centered {
                    xPos = (environment.container.effectiveContentSize.width - totalWidth()) / 2 + environment.container.contentInsets.leading
                } else {
                    xPos = interItemSpacing
                }
                
                let maxItemHeight = rowSizes.map(\.height).max() ?? 0
                let rowItems: [NSCollectionLayoutGroupCustomItem] = rowSizes.map {
                    let rect = CGRect(origin: CGPoint(x: xPos, y: verticalPosition + (maxItemHeight - $0.height) / 2), size: $0)
                    xPos += ($0.width + interItemSpacing)
                    return NSCollectionLayoutGroupCustomItem(frame: rect)
                }
                
                items.append(contentsOf: rowItems)
            }
            
            for (index, cellSize) in cellSizes.enumerated() {
                rowSizes.append(cellSize)
                
//                if totalWidth() > environment.container.effectiveContentSize.width {
//                    rowSizes.removeLast()
//                    addRowItems()
//                    yPos += cellSize.height
//                    rowSizes = [cellSize]
//                }
                
                if index == cellSizes.count - 1 {
                    addRowItems()
                }
            }
            
            return items
        }
    }
}
