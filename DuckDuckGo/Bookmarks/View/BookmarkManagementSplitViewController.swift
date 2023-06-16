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
import DependencyInjection

#if swift(>=5.9)
@Injectable
#endif
final class BookmarkManagementSplitViewController: NSSplitViewController, Injectable {

    let dependencies: DependencyStorage

    typealias InjectedDependencies = BookmarkManagementSidebarViewController.Dependencies & BookmarkManagementDetailViewController.Dependencies

    private enum Constants {
        static let storyboardName = "Bookmarks"
        static let identifier = "BookmarkManagementSplitViewController"
        static let detailIdentifier = "BookmarkManagementDetailViewController"
        static let sidebarIdentifier = "BookmarkManagementSidebarViewController"
    }

    static func create(dependencyProvider: DependencyProvider) -> BookmarkManagementSplitViewController {
        NSStoryboard(name: Constants.storyboardName, bundle: nil).instantiateController(identifier: Constants.identifier) { coder in
            BookmarkManagementSplitViewController(coder: coder, dependencyProvider: dependencyProvider)
        }
    }

    let sidebarViewController: BookmarkManagementSidebarViewController
    let detailViewController: BookmarkManagementDetailViewController

    weak var delegate: BrowserTabSelectionDelegate?

    private var selectedTabCancellable: AnyCancellable?

    init(coder: NSCoder, dependencyProvider: DependencyProvider) {
        self.dependencies = .init(dependencyProvider)
        sidebarViewController = NSStoryboard(name: Constants.storyboardName, bundle: nil).instantiateController(identifier: Constants.sidebarIdentifier) { coder in
            BookmarkManagementSidebarViewController(coder: coder, dependencyProvider: dependencyProvider)
        }
        detailViewController = NSStoryboard(name: Constants.storyboardName, bundle: nil).instantiateController(identifier: Constants.detailIdentifier) { coder in
            BookmarkManagementDetailViewController(coder: coder, dependencyProvider: dependencyProvider)
        }
        super.init(coder: coder)!
    }

    required init?(coder: NSCoder) {
        fatalError("\(Self.self): Bad initializer")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        sidebarViewController.loadView()
        detailViewController.loadView()

        self.addSplitViewItem(NSSplitViewItem(sidebarWithViewController: sidebarViewController))
        self.addSplitViewItem(NSSplitViewItem(viewController: detailViewController))

        splitView.setValue(NSColor(named: "DividerColor"), forKey: "dividerColor")
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
