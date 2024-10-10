//
//  BookmarkOutlineViewDataSourceTests.swift
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

import XCTest
@testable import DuckDuckGo_Privacy_Browser

class BookmarkOutlineViewDataSourceTests: XCTestCase {

    @MainActor
    func testWhenOutlineViewExpandsItem_ThenTheObjectIDIsAddedToExpandedItems() {
        let mockFolder = BookmarkFolder.mock
        let treeController = createTreeController(with: [mockFolder])
        let mockFolderNode = treeController.node(representing: mockFolder)!
        let dataSource = BookmarkOutlineViewDataSource(contentMode: .foldersOnly, bookmarkManager: LocalBookmarkManager(), treeController: treeController, sortMode: .manual)

        let notification = Notification(name: NSOutlineView.itemDidExpandNotification, object: nil, userInfo: ["NSObject": mockFolderNode])
        dataSource.outlineViewItemDidExpand(notification)

        XCTAssertEqual(dataSource.expandedNodesIDs, [mockFolder.id])
    }

    @MainActor
    func testWhenOutlineViewCollapsesItem_ThenTheObjectIDIsRemovedFromExpandedItems() {
        let mockFolder = BookmarkFolder.mock
        let treeController = createTreeController(with: [mockFolder])
        let mockFolderNode = treeController.node(representing: mockFolder)!
        let dataSource = BookmarkOutlineViewDataSource(contentMode: .foldersOnly, bookmarkManager: LocalBookmarkManager(), treeController: treeController, sortMode: .manual)

        let expandNotification = Notification(name: NSOutlineView.itemDidExpandNotification, object: nil, userInfo: ["NSObject": mockFolderNode])
        dataSource.outlineViewItemDidExpand(expandNotification)

        XCTAssertEqual(dataSource.expandedNodesIDs, [mockFolder.id])

        let collapseNotification = Notification(name: NSOutlineView.itemDidCollapseNotification, object: nil, userInfo: ["NSObject": mockFolderNode])
        dataSource.outlineViewItemDidCollapse(collapseNotification)

        XCTAssertEqual(dataSource.expandedNodesIDs, [])
    }

    @MainActor
    func testWhenGettingPasteboardWriterForItem_AndItemIsBookmarkEntity_ThenWriterIsReturned() {
        let mockFolder = BookmarkFolder.mock
        let mockOutlineView = NSOutlineView(frame: .zero)
        let treeController = createTreeController(with: [mockFolder])
        let mockFolderNode = treeController.node(representing: mockFolder)!
        let dataSource = BookmarkOutlineViewDataSource(contentMode: .foldersOnly, bookmarkManager: LocalBookmarkManager(), treeController: treeController, sortMode: .manual)

        let writer = dataSource.outlineView(mockOutlineView, pasteboardWriterForItem: mockFolderNode) as? FolderPasteboardWriter
        XCTAssertNotNil(writer)

        let writerDictionary = writer?.internalDictionary
        XCTAssertEqual(writerDictionary?["id"], mockFolder.id)
    }

    @MainActor
    func testWhenGettingPasteboardWriterForItem_AndItemIsNotBookmarkEntity_ThenNilIsReturned() {
        let mockFolder = BookmarkFolder.mock
        let mockOutlineView = NSOutlineView(frame: .zero)
        let treeController = createTreeController(with: [mockFolder])
        let dataSource = BookmarkOutlineViewDataSource(contentMode: .foldersOnly, bookmarkManager: LocalBookmarkManager(), treeController: treeController, sortMode: .manual)

        let spacerNode = BookmarkNode(representedObject: SpacerNode.blank, parent: nil)
        let writer = dataSource.outlineView(mockOutlineView, pasteboardWriterForItem: spacerNode) as? FolderPasteboardWriter
        XCTAssertNil(writer)
    }

    @MainActor
    func testWhenValidatingBookmarkDrop_AndDestinationIsFolder_ThenMoveDragOperationIsReturned() {
        let mockDestinationFolder = BookmarkFolder.mock
        let bookmarkStoreMock = BookmarkStoreMock(bookmarks: [mockDestinationFolder])
        let faviconManagerMock = FaviconManagerMock()
        let bookmarkManager = LocalBookmarkManager(bookmarkStore: bookmarkStoreMock, faviconManagement: faviconManagerMock)
        let dragDropManager = BookmarkDragDropManager(bookmarkManager: bookmarkManager)

        bookmarkManager.loadBookmarks()

        let treeDataSource = BookmarkSidebarTreeController(bookmarkManager: bookmarkManager)
        let treeController = BookmarkTreeController(dataSource: treeDataSource, sortMode: .manual)
        let mockDestinationNode = treeController.node(representing: mockDestinationFolder)!
        let dataSource = BookmarkOutlineViewDataSource(contentMode: .foldersOnly, bookmarkManager: LocalBookmarkManager(), treeController: treeController, dragDropManager: dragDropManager, sortMode: .manual)

        let bookmark = Bookmark(id: UUID().uuidString, url: "https://example.com", title: "Pasteboard Bookmark", isFavorite: false)
        let pasteboard = NSPasteboard.test()
        pasteboard.writeObjects([bookmark.pasteboardWriter])
        let draggingInfo = MockDraggingInfo(draggingPasteboard: pasteboard)
        let result = dataSource.outlineView(NSOutlineView(), validateDrop: draggingInfo, proposedItem: mockDestinationNode, proposedChildIndex: -1)

        XCTAssertEqual(result, .move)
    }

    @MainActor
    func testWhenValidatingFolderDrop_AndDestinationIsFolder_ThenMoveDragOperationIsReturned() {
        let mockDestinationFolder = BookmarkFolder.mock
        let bookmarkStoreMock = BookmarkStoreMock(bookmarks: [mockDestinationFolder])
        let faviconManagerMock = FaviconManagerMock()
        let bookmarkManager = LocalBookmarkManager(bookmarkStore: bookmarkStoreMock, faviconManagement: faviconManagerMock)
        let dragDropManager = BookmarkDragDropManager(bookmarkManager: bookmarkManager)

        bookmarkManager.loadBookmarks()

        let treeDataSource = BookmarkSidebarTreeController(bookmarkManager: bookmarkManager)
        let treeController = BookmarkTreeController(dataSource: treeDataSource, sortMode: .manual)
        let mockDestinationNode = treeController.node(representing: mockDestinationFolder)!
        let dataSource = BookmarkOutlineViewDataSource(contentMode: .foldersOnly, bookmarkManager: LocalBookmarkManager(), treeController: treeController, dragDropManager: dragDropManager, sortMode: .manual)

        let folder = BookmarkFolder(id: UUID().uuidString, title: "Pasteboard Folder")
        let pasteboard = NSPasteboard.test()
        pasteboard.writeObjects([folder.pasteboardWriter])
        let draggingInfo = MockDraggingInfo(draggingPasteboard: pasteboard)
        let result = dataSource.outlineView(NSOutlineView(), validateDrop: draggingInfo, proposedItem: mockDestinationNode, proposedChildIndex: -1)

        XCTAssertEqual(result, .move)
    }

    @MainActor
    func testWhenValidatingFolderDrop_AndDestinationIsSameFolder_ThenNoDragOperationIsReturned() {
        let mockDestinationFolder = BookmarkFolder.mock
        let bookmarkStoreMock = BookmarkStoreMock(bookmarks: [mockDestinationFolder])
        let faviconManagerMock = FaviconManagerMock()
        let bookmarkManager = LocalBookmarkManager(bookmarkStore: bookmarkStoreMock, faviconManagement: faviconManagerMock)
        let dragDropManager = BookmarkDragDropManager(bookmarkManager: bookmarkManager)

        bookmarkManager.loadBookmarks()

        let treeDataSource = BookmarkSidebarTreeController(bookmarkManager: bookmarkManager)
        let treeController = BookmarkTreeController(dataSource: treeDataSource, sortMode: .manual)
        let dataSource = BookmarkOutlineViewDataSource(contentMode: .foldersOnly, bookmarkManager: LocalBookmarkManager(), treeController: treeController, dragDropManager: dragDropManager, sortMode: .manual)
        let mockDestinationNode = treeController.node(representing: mockDestinationFolder)!

        let pasteboard = NSPasteboard.test()
        pasteboard.writeObjects([mockDestinationFolder.pasteboardWriter])
        let draggingInfo = MockDraggingInfo(draggingPasteboard: pasteboard)
        let result = dataSource.outlineView(NSOutlineView(), validateDrop: draggingInfo, proposedItem: mockDestinationNode, proposedChildIndex: -1)

        XCTAssertEqual(result, .none)
    }

    @MainActor
    func testWhenValidatingFolderDrop_AndDestinationIsAncestor_ThenNoneIsReturned() {
        let childFolder = BookmarkFolder(id: UUID().uuidString, title: "Child", parentFolderUUID: "rootfolder")
        let rootFolder = BookmarkFolder(id: "rootfolder", title: "Root", children: [childFolder])

        let bookmarkStoreMock = BookmarkStoreMock(bookmarks: [rootFolder])
        let faviconManagerMock = FaviconManagerMock()
        let bookmarkManager = LocalBookmarkManager(bookmarkStore: bookmarkStoreMock, faviconManagement: faviconManagerMock)
        let dragDropManager = BookmarkDragDropManager(bookmarkManager: bookmarkManager)

        bookmarkManager.loadBookmarks()

        let treeDataSource = BookmarkSidebarTreeController(bookmarkManager: bookmarkManager)
        let treeController = BookmarkTreeController(dataSource: treeDataSource, sortMode: .manual)
        let dataSource = BookmarkOutlineViewDataSource(contentMode: .foldersOnly, bookmarkManager: LocalBookmarkManager(), treeController: treeController, dragDropManager: dragDropManager, sortMode: .manual)
        let mockDestinationNode = treeController.node(representing: childFolder)!

        // Simulate dragging the root folder onto the child folder:
        let pasteboard = NSPasteboard.test()
        pasteboard.writeObjects([rootFolder.pasteboardWriter])
        let draggingInfo = MockDraggingInfo(draggingPasteboard: pasteboard)
        let result = dataSource.outlineView(NSOutlineView(), validateDrop: draggingInfo, proposedItem: mockDestinationNode, proposedChildIndex: -1)

        XCTAssertEqual(result, .none)
    }

    @MainActor
    func testWhenCellFiresDelegate_ThenOnMenuRequestedActionShouldFire() throws {
        // GIVEN
        let mockFolder = BookmarkFolder.mock
        let mockOutlineView = NSOutlineView(frame: .zero)
        let window = NSWindow(contentRect: .zero, styleMask: .closable, backing: .buffered, defer: false, screen: nil)
        window.contentView = mockOutlineView
        let treeController = createTreeController(with: [mockFolder])
        let mockFolderNode = treeController.node(representing: mockFolder)!
        let dataSource = BookmarkOutlineViewDataSource(contentMode: .foldersOnly, bookmarkManager: LocalBookmarkManager(), treeController: treeController, sortMode: .manual)
        let cell = try XCTUnwrap(dataSource.outlineView(mockOutlineView, viewFor: nil, item: mockFolderNode) as? BookmarkOutlineCellView)
        let row = NSView(frame: .zero)
        row.addSubview(cell)
        mockOutlineView.addSubview(row)

        class MockMenu: NSMenu {
            var didCallPopUp = false
            var cell: NSView?
            override func popUp(positioning item: NSMenuItem?, at location: NSPoint, in view: NSView?) -> Bool {
                XCTAssertEqual(view, cell)
                didCallPopUp = true
                return false
            }
        }
        let menu = MockMenu()
        menu.cell = cell
        mockOutlineView.menu = menu

        // WHEN
        cell.delegate?.outlineCellViewRequestedMenu(cell)

        // THEN
        XCTAssertTrue((mockOutlineView.menu as! MockMenu).didCallPopUp)
    }

    @MainActor
    func testWhenContentModeIsBookmarksAndFolders_ThenCellShouldHaveShouldMenuButtonFlagTrue() throws {
        // GIVEN
        let mockFolder = BookmarkFolder.mock
        let mockOutlineView = NSOutlineView(frame: .zero)
        let treeController = createTreeController(with: [mockFolder])
        let mockFolderNode = treeController.node(representing: mockFolder)!
        let dataSource = BookmarkOutlineViewDataSource(contentMode: .bookmarksAndFolders, bookmarkManager: LocalBookmarkManager(), treeController: treeController, sortMode: .manual)

        // WHEN
        let cell = try XCTUnwrap(dataSource.outlineView(mockOutlineView, viewFor: nil, item: mockFolderNode) as? BookmarkOutlineCellView)

        // THEN
        XCTAssertFalse(cell.shouldShowChevron)
    }

    @MainActor
    func testWhenContentModeIsFolders_ThenCellShouldHaveShouldMenuButtonFlagFalse() throws {
        // GIVEN
        let mockFolder = BookmarkFolder.mock
        let mockOutlineView = NSOutlineView(frame: .zero)
        let treeController = createTreeController(with: [mockFolder])
        let mockFolderNode = treeController.node(representing: mockFolder)!
        let dataSource = BookmarkOutlineViewDataSource(contentMode: .foldersOnly, bookmarkManager: LocalBookmarkManager(), treeController: treeController, sortMode: .manual)

        // WHEN
        let cell = try XCTUnwrap(dataSource.outlineView(mockOutlineView, viewFor: nil, item: mockFolderNode) as? BookmarkOutlineCellView)

        // THEN
        XCTAssertFalse(cell.shouldShowChevron)
    }

    @MainActor
    func testWhenContentModeIsBookmarksMenu_ThenCellShouldHaveShouldMenuButtonFlagFalse() throws {
        // GIVEN
        let mockFolder = BookmarkFolder.mock
        let mockOutlineView = NSOutlineView(frame: .zero)
        let treeController = createTreeController(with: [mockFolder])
        let mockFolderNode = treeController.node(representing: mockFolder)!
        let dataSource = BookmarkOutlineViewDataSource(contentMode: .bookmarksMenu, bookmarkManager: LocalBookmarkManager(), treeController: treeController, sortMode: .manual)

        // WHEN
        let cell = try XCTUnwrap(dataSource.outlineView(mockOutlineView, viewFor: nil, item: mockFolderNode) as? BookmarkOutlineCellView)

        // THEN
        XCTAssertTrue(cell.shouldShowChevron)
    }

    // MARK: - Private

    @MainActor
    private func createTreeController(with bookmarks: [BaseBookmarkEntity]) -> BookmarkTreeController {
        let bookmarkStoreMock = BookmarkStoreMock(bookmarks: bookmarks)
        let faviconManagerMock = FaviconManagerMock()
        let bookmarkManager = LocalBookmarkManager(bookmarkStore: bookmarkStoreMock, faviconManagement: faviconManagerMock)
        bookmarkManager.loadBookmarks()

        let treeDataSource = BookmarkSidebarTreeController(bookmarkManager: bookmarkManager)
        return BookmarkTreeController(dataSource: treeDataSource, sortMode: .manual)
    }

}

extension Bookmark {

    static var mock: Bookmark = Bookmark(id: UUID().uuidString,
                                         url: URL.duckDuckGo.absoluteString,
                                         title: "Title",
                                         isFavorite: false)

}

extension BookmarkFolder {

    static var mock = BookmarkFolder(id: UUID().uuidString, title: "Title")

}

class MockDraggingInfo: NSObject, NSDraggingInfo {

    var draggingDestinationWindow: NSWindow?

    var draggingSourceOperationMask: NSDragOperation

    var draggingLocation: NSPoint

    var draggedImageLocation: NSPoint

    var draggedImage: NSImage?

    var draggingPasteboard: NSPasteboard

    var draggingSource: Any?

    var draggingSequenceNumber: Int

    var draggingFormation: NSDraggingFormation

    var animatesToDestination: Bool

    var numberOfValidItemsForDrop: Int

    var springLoadingHighlight: NSSpringLoadingHighlight

    init(draggingDestinationWindow: NSWindow? = nil, draggingSourceOperationMask: NSDragOperation = .move, draggingLocation: NSPoint = .zero, draggedImageLocation: NSPoint = .zero, draggedImage: NSImage? = nil, draggingPasteboard: NSPasteboard, draggingSource: Any? = nil, draggingSequenceNumber: Int = 0, draggingFormation: NSDraggingFormation = .default, animatesToDestination: Bool = true, numberOfValidItemsForDrop: Int = 0, springLoadingHighlight: NSSpringLoadingHighlight = .standard) {
        self.draggingDestinationWindow = draggingDestinationWindow
        self.draggingSourceOperationMask = draggingSourceOperationMask
        self.draggingLocation = draggingLocation
        self.draggedImageLocation = draggedImageLocation
        self.draggedImage = draggedImage
        self.draggingPasteboard = draggingPasteboard
        self.draggingSource = draggingSource
        self.draggingSequenceNumber = draggingSequenceNumber
        self.draggingFormation = draggingFormation
        self.animatesToDestination = animatesToDestination
        self.numberOfValidItemsForDrop = numberOfValidItemsForDrop
        self.springLoadingHighlight = springLoadingHighlight
    }

    func slideDraggedImage(to screenPoint: NSPoint) {}

    func enumerateDraggingItems(options enumOpts: NSDraggingItemEnumerationOptions = [], for view: NSView?, classes classArray: [AnyClass], searchOptions: [NSPasteboard.ReadingOptionKey: Any] = [:], using block: @escaping (NSDraggingItem, Int, UnsafeMutablePointer<ObjCBool>) -> Void) {
        fatalError()
    }

    func resetSpringLoading() {
        fatalError()
    }

}
