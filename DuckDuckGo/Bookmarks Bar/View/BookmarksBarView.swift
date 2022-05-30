//
//  BookmarksBarView.swift
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

protocol BookmarksBarViewDelegate: AnyObject {
    
    func draggingEntered(draggingInfo: NSDraggingInfo)
    func draggingExited(draggingInfo: NSDraggingInfo?)
    func draggingUpdated(draggingInfo: NSDraggingInfo)
    func draggingEnded(draggingInfo: NSDraggingInfo)
    
}

final class BookmarksBarView: ColorView {
    
    weak var delegate: BookmarksBarViewDelegate?
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        delegate?.draggingEntered(draggingInfo: sender)
        return sender.draggingSourceOperationMask
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {
        delegate?.draggingExited(draggingInfo: sender)
    }
    
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        delegate?.draggingUpdated(draggingInfo: sender)
        return sender.draggingSourceOperationMask
    }
    
    override func draggingEnded(_ sender: NSDraggingInfo) {
        print(#function)
        
        if let button = sender.draggingSource as? BookmarksBarButton {
            button.isHidden = false
        }
        
        delegate?.draggingEnded(draggingInfo: sender)
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        print("Perform drag operation")
        return true
    }
    
}

extension NSDraggingInfo {
    
    var width: CGFloat {
        return draggedImage?.size.width ?? 0
    }
    
}
