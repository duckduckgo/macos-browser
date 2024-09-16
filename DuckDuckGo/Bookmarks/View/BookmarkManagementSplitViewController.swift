//
//  BookmarkManagementSplitViewController.swift
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

import AppKit

final class BookmarkManagementSplitViewController: NSSplitViewController {

    private let bookmarkManager: BookmarkManager
    weak var delegate: BrowserTabSelectionDelegate?

    lazy var sidebarViewController: BookmarkManagementSidebarViewController = BookmarkManagementSidebarViewController(bookmarkManager: bookmarkManager)
    lazy var detailViewController: BookmarkManagementDetailViewController = BookmarkManagementDetailViewController(bookmarkManager: bookmarkManager)

    init(bookmarkManager: BookmarkManager = LocalBookmarkManager.shared) {
        self.bookmarkManager = bookmarkManager
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("\(type(of: self)): Bad initializer")
    }

    override func loadView() {
        title = UserText.bookmarks

        splitView.dividerStyle = .thin
        splitView.isVertical = true
        splitView.setValue(NSColor.divider, forKey: #keyPath(NSSplitView.dividerColor))

        let sidebarViewItem = NSSplitViewItem(contentListWithViewController: sidebarViewController)
        sidebarViewItem.minimumThickness = 256
        sidebarViewItem.maximumThickness = 256

        addSplitViewItem(sidebarViewItem)

        let detailViewItem = NSSplitViewItem(viewController: detailViewController)
        addSplitViewItem(detailViewItem)

        view = splitView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        sidebarViewController.delegate = self
        detailViewController.delegate = self
    }

}

extension BookmarkManagementSplitViewController: BookmarkManagementSidebarViewControllerDelegate {

    func sidebarSelectionStateDidChange(_ state: BookmarkManagementSidebarViewController.SelectionState) {
        detailViewController.update(selectionState: state)
    }

    func sidebarSelectedTabContentDidChange(_ content: Tab.TabContent) {
        delegate?.selectedTabContent(content)
    }

}

extension BookmarkManagementSplitViewController: BookmarkManagementDetailViewControllerDelegate {

    func bookmarkManagementDetailViewControllerDidSelectFolder(_ folder: BookmarkFolder) {
        sidebarViewController.select(folder: folder)
    }

    func bookmarkManagementDetailViewControllerDidStartSearching() {
        sidebarViewController.selectBookmarksFolder()
    }

    func bookmarkManagementDetailViewControllerShowInFolder(_ folder: BookmarkFolder) {
        sidebarViewController.select(folder: folder)
    }

    func bookmarkManagementDetailViewControllerSortChanged(_ mode: BookmarksSortMode) {
        sidebarViewController.sortModeChanged(mode)
    }

}

#if DEBUG
private let previewSize = NSSize(width: 700, height: 660)
@available(macOS 14.0, *)
#Preview(traits: previewSize.fixedLayout) { {

    let vc = BookmarkManagementSplitViewController(bookmarkManager: {
        let bkman = LocalBookmarkManager(bookmarkStore: BookmarkStoreMock(bookmarks: [
            BookmarkFolder(id: "1", title: "Folder 1", children: [
                BookmarkFolder(id: "2", title: "Nested Folder", children: [
                    Bookmark(id: "b1", url: URL.duckDuckGo.absoluteString, title: "DuckDuckGo", isFavorite: false, parentFolderUUID: "2")
                ])
            ]),
            BookmarkFolder(id: "3", title: "Another Folder", children: [
                BookmarkFolder(id: "4", title: "Nested Folder", children: [
                    BookmarkFolder(id: "5", title: "Another Nested Folder", children: [
                        Bookmark(id: "b2", url: URL.duckDuckGo.absoluteString, title: "DuckDuckGo", isFavorite: false, parentFolderUUID: "5")
                    ])
                ])
            ]),
            Bookmark(id: "b3", url: URL.duckDuckGo.absoluteString, title: "Bookmark 1", isFavorite: false, parentFolderUUID: ""),
            Bookmark(id: "b4", url: URL.duckDuckGo.absoluteString, title: "Bookmark 2", isFavorite: false, parentFolderUUID: ""),
            Bookmark(id: "b5", url: URL.duckDuckGo.absoluteString, title: "DuckDuckGo", isFavorite: false, parentFolderUUID: "")
        ]))
        bkman.loadBookmarks()
        customAssertionFailure = { _, _, _ in }

        return bkman
    }())
    vc.preferredContentSize = previewSize
    return vc

}() }
#endif
