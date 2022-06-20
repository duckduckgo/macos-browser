//
//  BookmarksBarViewModelTests.swift
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

import XCTest
@testable import DuckDuckGo_Privacy_Browser

class BookmarksBarViewModelTests: XCTestCase {

    func testWhenMouseDraggedEventIsReceived_ThenViewModelEntersBeginningDragState() throws {
        let mockBookmarksManager = createMockBookmarksManager()
        let viewModel = BookmarksBarViewModel(bookmarkManager: mockBookmarksManager)
        
        XCTAssertEqual(viewModel.state, .idle)
        viewModel.handle(event: .mouseDragged(buttonIndex: 0, location: .zero))
        XCTAssertEqual(viewModel.state, .beginningDrag(originalLocation: .zero))
    }
    
    func testWhenStateIsBeginningDrag_AndMouseUpEventIsReceivedBeforeCrossingDragSessionThreshold_ThenStateResetsToIdle() throws {
        let mockBookmarksManager = createMockBookmarksManager()
        let viewModel = BookmarksBarViewModel(bookmarkManager: mockBookmarksManager)
        
        viewModel.handle(event: .mouseDragged(buttonIndex: 0, location: .zero))
        XCTAssertEqual(viewModel.state, .beginningDrag(originalLocation: .zero))
        
        viewModel.handle(event: .mouseDragged(buttonIndex: 0, location: CGPoint(x: 0, y: 1)))
        XCTAssertEqual(viewModel.state, .beginningDrag(originalLocation: .zero))
        
        viewModel.handle(event: .mouseUp)
        XCTAssertEqual(viewModel.state, .idle)
    }
    
    func testWhenStateIsBeginningDrag_AndViewCrossesDragSessionThreshold_ThenStateEqualsDragging() throws {
        let expectedItem = BookmarksBarViewModel.ExistingDraggedItemData(originalIndex: 0, title: "Title")
        
        let mockBookmarksManager = createMockBookmarksManager()
        let viewModel = BookmarksBarViewModel(bookmarkManager: mockBookmarksManager)
        
        viewModel.handle(event: .mouseDragged(buttonIndex: 0, location: .zero))
        XCTAssertEqual(viewModel.state, .beginningDrag(originalLocation: .zero))
        
        viewModel.handle(event: .mouseDragged(buttonIndex: 0, location: CGPoint(x: 10, y: 10)))
        XCTAssertEqual(viewModel.state, .draggingExistingItem(draggedItemData: expectedItem))
        
        viewModel.handle(event: .mouseUp)
        XCTAssertEqual(viewModel.state, .idle)
    }
    
    private func createMockBookmarksManager() -> BookmarkManager {
        let mockBookmarkStore = BookmarkStoreMock()
        let mockFaviconManager = FaviconManagerMock()
        return LocalBookmarkManager(bookmarkStore: mockBookmarkStore, faviconManagement: mockFaviconManager)
    }

}
