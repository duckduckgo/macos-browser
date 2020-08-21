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

class TabBarCollectionView: NSCollectionView {
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        let nib = NSNib(nibNamed: "TabBarViewItem", bundle: nil)
        register(nib, forItemWithIdentifier: TabBarViewItem.identifier)

        // Register for the dropped object types we can accept.
        registerForDraggedTypes([NSPasteboard.PasteboardType.string])
        // Enable dragging items within and into our CollectionView.
        setDraggingSourceOperationMask(NSDragOperation.move, forLocal: false)
    }

    func clearSelection() {
        deselectItems(at: selectionIndexPaths)
    }
    
    func scrollToSelected() {
        guard selectionIndexPaths.count == 1, let indexPath = selectionIndexPaths.first else {
            os_log("TabBarCollectionView: More than 1 item highlighted", log: OSLog.Category.general, type: .error)
            return
        }

        let rect = frameForItem(at: indexPath.item)
        animator().performBatchUpdates({
            animator().scrollToVisible(rect)
        }, completionHandler: nil)
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
}
