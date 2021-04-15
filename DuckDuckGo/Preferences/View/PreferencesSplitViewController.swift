//
//  PreferencesSplitViewController.swift
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

enum PreferencesDetailViewType {
    case preferencesList(selectedRowIndex: Int)
    case about
}

final class PreferencesSplitViewController: NSSplitViewController {

    enum Constants {
        static let storyboardName = "Preferences"
        static let identifier = "PreferencesSplitViewController"
    }

    static func create() -> PreferencesSplitViewController {
        let storyboard = NSStoryboard(name: Constants.storyboardName, bundle: nil)
        return storyboard.instantiateController(identifier: Constants.identifier)
    }

    private var cancellables = Set<AnyCancellable>()

    // swiftlint:disable force_cast
    var sidebarViewController: PreferencesSidebarViewController {
        return splitViewItems[0].viewController as! PreferencesSidebarViewController
    }
    // swiftlint:enable force_cast

    var preferencesListDetailViewController: PreferencesListViewController? {
        return splitViewItems[1].viewController as? PreferencesListViewController
    }

    private let preferenceSections = PreferenceSections()

    override func viewDidLoad() {
        super.viewDidLoad()

        splitView.setValue(NSColor.windowBackgroundColor, forKey: "dividerColor")
        sidebarViewController.delegate = self
        subscribeToListViewControllerVisibleIndex()
    }

    private func subscribeToListViewControllerVisibleIndex() {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()

        preferencesListDetailViewController?.$firstVisibleCellIndex.sink { [weak self] index in
            self?.sidebarViewController.select(rowAtIndex: index)
        }.store(in: &cancellables)
    }

}

extension PreferencesSplitViewController: PreferencesSidebarViewControllerDelegate {

    func selected(detailViewType: PreferencesDetailViewType) {
        switch detailViewType {
        case .preferencesList(let selectedIndex):
            if let listViewController = self.preferencesListDetailViewController {
                listViewController.select(row: selectedIndex)
            } else {
                let preferencesListViewController = PreferencesListViewController.create()
                showDetailViewController(preferencesListViewController)
                preferencesListDetailViewController?.select(row: selectedIndex)
                subscribeToListViewControllerVisibleIndex()
            }
        case .about:
            let preferencesAboutViewController = PreferencesAboutViewController.create()
            showDetailViewController(preferencesAboutViewController)
        }
    }

    private func showDetailViewController(_ viewController: NSViewController) {
        let splitViewItem = NSSplitViewItem(viewController: viewController)
        splitViewItems[1] = splitViewItem
    }

}
