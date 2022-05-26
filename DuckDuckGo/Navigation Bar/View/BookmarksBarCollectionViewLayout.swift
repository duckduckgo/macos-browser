//
//  BookmarksBarCollectionViewLayout.swift
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

import Foundation

final class BookmarksBarCollectionViewLayout: NSCollectionViewFlowLayout {
    
    override func layoutAttributesForItem(at indexPath: IndexPath) -> NSCollectionViewLayoutAttributes? {
        print("Returning attributes for indexPath")
        return super.layoutAttributesForItem(at: indexPath)
    }
    
    override func layoutAttributesForElements(in rect: NSRect) -> [NSCollectionViewLayoutAttributes] {
        let originalAttributes = super.layoutAttributesForElements(in: rect)
        
        guard let attributes = NSArray(array: originalAttributes, copyItems: true) as? [NSCollectionViewLayoutAttributes] else {
            return []
        }
        
        guard let lastAttribute = originalAttributes.last else {
            return originalAttributes
        }
        
        let widthForAllElements = lastAttribute.frame.origin.x + lastAttribute.frame.size.width
        let halfWidth = (rect.width / 2)
        let halfElementsWidth = widthForAllElements / 2
        let elementOffset = halfWidth - halfElementsWidth
        
        for attribute in attributes {
            var modifiedFrame = attribute.frame
            modifiedFrame.origin.x += elementOffset
            
            attribute.frame = modifiedFrame
        }
        
        return attributes
    }
    
}
