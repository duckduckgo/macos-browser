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

    private enum Constants {
        static let storyboardName = "Bookmarks"
        static let identifier = "BookmarkManagementSplitViewController"
    }

    static func create() -> BookmarkManagementSplitViewController {
        let storyboard = NSStoryboard(name: Constants.storyboardName, bundle: nil)
        return storyboard.instantiateController(identifier: Constants.identifier)
    }

    // swiftlint:disable force_cast
    var sidebarViewController: BookmarkManagementSidebarViewController {
        return splitViewItems[0].viewController as! BookmarkManagementSidebarViewController
    }

    var detailViewController: BookmarkManagementDetailViewController {
        return splitViewItems[1].viewController as! BookmarkManagementDetailViewController
    }
    // swiftlint:enable force_cast

    weak var delegate: BrowserTabSelectionDelegate?

    private var selectedTabCancellable: AnyCancellable?

    override func viewDidLoad() {
        super.viewDidLoad()

        splitView.setValue(NSColor(named: "DividerColor"), forKey: "dividerColor")
        sidebarViewController.delegate = self
        detailViewController.delegate = self
        sidebarViewController.tabSwitcherButton.displayBrowserTabButtons(withSelectedTab: .bookmarks)

        selectedTabCancellable = sidebarViewController.tabSwitcherButton.selectionPublisher.dropFirst().sink { [weak self] index in
            self?.delegate?.selectedTab(at: index)
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        adjustFirstResponder()
    }

    func adjustFirstResponder() {
        sidebarViewController.adjustFirstResponder()
    }

    func recalculatePartialKeyViewLoop(after firstKeyView: NSView) -> NSView {
        guard NSApp.isFullKeyboardAccessEnabled else { return firstKeyView }

        firstKeyView.nextKeyView = sidebarViewController.tabSwitcherButton

        sidebarViewController.tabSwitcherButton.nextKeyView = sidebarViewController.outlineView
        sidebarViewController.outlineView.nextKeyView = detailViewController.newBookmarkButton
        detailViewController.newBookmarkButton.nextKeyView = detailViewController.newFolderButton
        detailViewController.newFolderButton.nextKeyView = detailViewController.tableView

        return detailViewController.tableView
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
        sidebarViewController.select(folder)
    }

    func bookmarkManagementDetailViewControllerSelectParentFolder(of folder: BookmarkFolder) {
        sidebarViewController.selectParent(of: folder)
        detailViewController.select(folder)
    }

}
