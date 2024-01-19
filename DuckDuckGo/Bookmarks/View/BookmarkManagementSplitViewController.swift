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
import Combine

final class BookmarkManagementSplitViewController: NSSplitViewController {

    weak var delegate: BrowserTabSelectionDelegate?

    lazy var sidebarViewController: BookmarkManagementSidebarViewController = BookmarkManagementSidebarViewController()
    lazy var detailViewController: BookmarkManagementDetailViewController = BookmarkManagementDetailViewController()

    init() {
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
        sidebarViewItem.holdingPriority = .init(rawValue: 255)
        addSplitViewItem(sidebarViewItem)

        let detailViewItem = NSSplitViewItem(viewController: detailViewController)
        addSplitViewItem(detailViewItem)

        view = splitView
    }

    private var selectedTabCancellable: AnyCancellable?

    override func viewDidLoad() {
        super.viewDidLoad()

        sidebarViewController.delegate = self
        detailViewController.delegate = self
        sidebarViewController.tabSwitcherButton.displayBrowserTabButtons(withSelectedTab: .bookmarks)

        selectedTabCancellable = sidebarViewController.tabSwitcherButton.selectionPublisher.dropFirst().sink { [weak self] index in
            self?.delegate?.selectedTab(at: index)
        }
    }

}

extension BookmarkManagementSplitViewController: BookmarkManagementSidebarViewControllerDelegate {

    func bookmarkManagementSidebarViewController(_ sidebarViewController: BookmarkManagementSidebarViewController,
                                                 enteredState state: BookmarkManagementSidebarViewController.SelectionState) {
        detailViewController.update(selectionState: state)
    }

}

extension BookmarkManagementSplitViewController: BookmarkManagementDetailViewControllerDelegate {

    func bookmarkManagementDetailViewControllerDidSelectFolder(_ folder: BookmarkFolder) {
        sidebarViewController.select(folder: folder)
    }

}
