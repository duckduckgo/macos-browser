//
//  BookmarksBarViewModel.swift
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
import Combine
import Foundation

final class BookmarksBarViewModel: NSObject {
    
    // MARK: Enums
    
    enum Constants {
        static let distanceRequiredForDragging: CGFloat = 7
        static let buttonSpacing: CGFloat = 8
        static let buttonHeight: CGFloat = 28
        static let maximumButtonWidth: CGFloat = 150
    }
    
    enum ViewState: Equatable {
        case idle
        case beginningDrag(originalLocation: CGPoint)
        case draggingExistingItem(draggedItemData: DraggedItemData)
        case draggingNewItem(draggedItemData: DraggedItemData)
        
        var isDragging: Bool {
            switch self {
            case .draggingExistingItem, .draggingNewItem: return true
            case .idle, .beginningDrag: return false
            }
        }
    }
    
    enum ViewEvent {
        case containerFrameChanged(CGRect)
        case mouseDown(CGPoint)
        case mouseDragged(buttonIndex: Int, location: CGPoint)
        case mouseUp
        case beganDraggingSession
    }
    
    // MARK: State
    
    struct ButtonLayoutData {
        let cumulativeButtonWidth: CGFloat = 0
        let cumulativeSpacingWidth: CGFloat = 0
        let totalButtonListWidth: CGFloat = 0
    }
    
    struct DraggedItemData: Equatable {
        let proposedDropIndex: Int
        let proposedItemWidth: CGFloat
    }

    @Published var isDragging = false {
        didSet {
            print("DID SET: isDragging = \(isDragging)")
        }
    }
    
    @Published private(set) var state: ViewState = .idle
    private(set) var buttonLayoutData: ButtonLayoutData = ButtonLayoutData()
    
    private let bookmarkManager: BookmarkManager
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: Functions

    init(bookmarkManager: BookmarkManager = LocalBookmarkManager.shared) {
        self.bookmarkManager = bookmarkManager
    }
    
    func handle(event: ViewEvent) {
        switch event {
        case .mouseDown:
            break
        case .mouseDragged(let draggedButtonIndex, let currentLocation):
            if case let .beginningDrag(originalLocation) = self.state {
                let distance = originalLocation.distance(to: currentLocation)
                if distance > Constants.distanceRequiredForDragging {
                    self.state = .draggingExistingItem(draggedItemData: DraggedItemData(proposedDropIndex: 0, proposedItemWidth: 0))
                }
            } else {
                self.state = .beginningDrag(originalLocation: currentLocation)
            }
        case .mouseUp:
            self.state = .idle
        case .beganDraggingSession:
            break
        case .containerFrameChanged:
            // Calculate new frames
            break
        }
    }
 
}

// MARK: - Dragging Source

extension BookmarksBarViewModel: NSDraggingSource {

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        switch context {
        case .withinApplication:
            print("RETURNING GENERIC")
            return .generic
        case .outsideApplication:
            print("RETURNING EMPTY")
            return []
        @unknown default: fatalError()
        }
    }

}

// MARK: - Dragging Pasteboard Data

extension BookmarksBarViewModel: NSPasteboardItemDataProvider {
    
    func pasteboard(_ pasteboard: NSPasteboard?, item: NSPasteboardItem, provideDataForType type: NSPasteboard.PasteboardType) {
        print(#function)
        
        // TODO: Read data about actual dragged item
        let string = "https://duckduckgo.com/".data(using: .utf8)!
    
        switch type {
        case .URL: item.setData(string, forType: type)
        case .string: item.setData(string, forType: type)
        default: break
        }
    }

}
