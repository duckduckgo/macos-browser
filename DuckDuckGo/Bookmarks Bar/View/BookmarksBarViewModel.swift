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
        static let labelFont = NSFont.systemFont(ofSize: 13)
    }
    
    enum ViewState: Equatable {
        case idle
        case beginningDrag(originalLocation: CGPoint)
        case draggingExistingItem(draggedItemData: NewDraggedItemData)
        case draggingNewItem(draggedItemData: NewDraggedItemData)
        
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
        case draggingEntered
        case draggingEnded
    }
    
    // MARK: State
    
    struct BookmarkButtonData {
        let button: BookmarksBarButton
        let bookmarkViewModel: BookmarkViewModel
    }
    
    struct ButtonRowLayoutData {
        let cumulativeButtonWidth: CGFloat = 0
        let cumulativeSpacingWidth: CGFloat = 0
        let totalButtonListWidth: CGFloat = 0
    }
    
    struct NewDraggedItemData: Equatable {
        let proposedDropIndex: Int
        let proposedItemWidth: CGFloat

        // let title: String
        // let url: URL
    }
    
    struct ExistingDraggedItemData: Equatable {
        let originalIndex: Int
        let title: String
    }

    @Published var isDragging = false {
        didSet {
            print("DID SET: isDragging = \(isDragging)")
        }
    }
    
    @Published private(set) var state: ViewState = .idle
    private(set) var buttonLayoutData: ButtonRowLayoutData = ButtonRowLayoutData()
    
    private let bookmarkManager: BookmarkManager
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: Functions

    init(bookmarkManager: BookmarkManager = LocalBookmarkManager.shared) {
        self.bookmarkManager = bookmarkManager
    }
    
    func handle(event: ViewEvent) {
        switch event {
        case .containerFrameChanged:
            // Calculate new frames
            break
        case .mouseDown:
            break
        case .mouseDragged(let draggedButtonIndex, let currentLocation):
            if case let .beginningDrag(originalLocation) = self.state {
                let distance = originalLocation.distance(to: currentLocation)
                if distance > Constants.distanceRequiredForDragging {
                    self.state = .draggingExistingItem(draggedItemData: NewDraggedItemData(proposedDropIndex: 0, proposedItemWidth: 0))
                }
            } else {
                self.state = .beginningDrag(originalLocation: currentLocation)
            }
        case .mouseUp:
            self.state = .idle
        case .draggingEntered:
            if state == .idle {
                print("IDLE STATE, NEW ITEM")
            } else {
                print("NON-IDLE STATE, EXISTING ITEM")
            }
        case .draggingEnded:
            // Need to do anything here?
            break
        }
    }
    
    // MARK: - Button Creation
    
    func createButtons(for entities: [BaseBookmarkEntity]) -> [BookmarkButtonData] {
        return entities.compactMap { entity in
            let viewModel = BookmarkViewModel(entity: entity)

            if let bookmark = entity as? Bookmark {
                let button = BookmarksBarButton(bookmark: bookmark)
                configureBookmarkButton(button: button, withTitle: bookmark.title)
                
                return BookmarkButtonData(button: button, bookmarkViewModel: viewModel)
            } else if let folder = entity as? BookmarkFolder {
                let button = BookmarksBarButton(folder: folder)
                configureBookmarkButton(button: button, withTitle: folder.title)
                
                return BookmarkButtonData(button: button, bookmarkViewModel: viewModel)
            } else {
                assertionFailure("Tried to display bookmarks bar button for unsupported type: \(entity)")
                return nil
            }
        }
    }
    
    private func configureBookmarkButton(button: BookmarksBarButton, withTitle title: String) {
        button.title = title
        button.isBordered = false
        button.lineBreakMode = .byTruncatingMiddle
        button.sizeToFit()
        
        var buttonFrame = button.frame
        buttonFrame.size.width = min(BookmarksBarViewModel.Constants.maximumButtonWidth, buttonFrame.size.width)
        button.frame = buttonFrame
    }
    
    // MARK: - Menu Item Creation
 
}

// MARK: - Dragging Source

extension BookmarksBarViewModel: NSDraggingSource {

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        switch context {
        case .withinApplication:
            return .generic
        case .outsideApplication:
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
        case .URL:
            item.setData(string, forType: type)
        case .string:
            item.setData(string, forType: type)
        default:
            assertionFailure("Tried to get data for unsupported pasteboard type")
        }
    }

}
