//
//  HorizontallyCenteredLayout.swift
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

extension NSCollectionLayoutGroup {

    static func horizontallyCentered(cellSizes: [CGSize], interItemSpacing: CGFloat = 6, centered: Bool = true) -> NSCollectionLayoutGroup {
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(28))
        
        return custom(layoutSize: groupSize) { environment in
            let verticalPosition: CGFloat = environment.container.contentInsets.top

            var items: [NSCollectionLayoutGroupCustomItem] = []
            let totalWidth = cellSizes.map(\.width).reduce(0) {
                $0 == 0 ? $1 : $0 + interItemSpacing + $1
            }
            
            var xPos: CGFloat
            
            if centered {
                xPos = (environment.container.effectiveContentSize.width - totalWidth) / 2 + environment.container.contentInsets.leading
            } else {
                xPos = interItemSpacing
            }
            
            let maxItemHeight = cellSizes.map(\.height).max() ?? 0

            let rowItems: [NSCollectionLayoutGroupCustomItem] = cellSizes.map {
                let rect = CGRect(origin: CGPoint(x: xPos, y: verticalPosition + (maxItemHeight - $0.height) / 2), size: $0)
                xPos += ($0.width + interItemSpacing)
                return NSCollectionLayoutGroupCustomItem(frame: rect)
            }
            
            items.append(contentsOf: rowItems)
            
            return items
        }
    }
}
