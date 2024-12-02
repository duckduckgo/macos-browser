//
//  FirePopoverWrapperViewController.swift
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

import Foundation

final class FirePopoverWrapperViewController: NSViewController {

    private lazy var infoViewController: FireInfoViewController = {
        let fireInfoViewController = FireInfoViewController()
        fireInfoViewController.delegate = self
        return fireInfoViewController
    }()

    private lazy var popoverViewController: FirePopoverViewController? = {
        guard let tabCollectionViewModel = tabCollectionViewModel else {
            assertionFailure("Attempted to display Fire Popover without an associated TabCollectionViewModel")
            return nil
        }
        let firePopoverViewController = FirePopoverViewController(fireViewModel: fireViewModel, tabCollectionViewModel: tabCollectionViewModel)
        firePopoverViewController.delegate = self
        return firePopoverViewController
    }()

    @UserDefaultsWrapper(key: .fireInfoPresentedOnce, defaultValue: false)
    var infoPresentedOnce: Bool

    private let fireViewModel: FireViewModel
    private weak var tabCollectionViewModel: TabCollectionViewModel?

    required init?(coder: NSCoder) {
        fatalError("FirePopoverWrapperViewController: Bad initializer")
    }

    init(fireViewModel: FireViewModel, tabCollectionViewModel: TabCollectionViewModel) {
        self.fireViewModel = fireViewModel
        self.tabCollectionViewModel = tabCollectionViewModel

        super.init(nibName: nil, bundle: nil)
    }

    override func loadView() {
        view = NSView()
        guard let tabCollectionViewModel, let popoverViewController else { return }

        let infoIsVisible = !infoPresentedOnce && !tabCollectionViewModel.isBurner
        self.addAndLayoutChild(popoverViewController)
        popoverViewController.view.isHidden = infoIsVisible

        if infoIsVisible {
            self.addAndLayoutChild(infoViewController)
        }
    }

}

extension FirePopoverWrapperViewController: FireInfoViewControllerDelegate {

    func fireInfoViewControllerDidConfirm(_ fireInfoViewController: FireInfoViewController) {
        infoPresentedOnce = true

        fireInfoViewController.removeFromParent()
        fireInfoViewController.view.removeFromSuperview()

        popoverViewController?.view.isHidden = false
    }

}

extension FirePopoverWrapperViewController: FirePopoverViewControllerDelegate {

    func firePopoverViewControllerDidClear(_ firePopoverViewController: FirePopoverViewController) {
        dismiss()
    }

    func firePopoverViewControllerDidCancel(_ firePopoverViewController: FirePopoverViewController) {
        dismiss()
    }

}

@available(macOS 14.0, *)
#Preview("First time", traits: .fixedLayout(width: 344, height: 650)) { {
    let tabCollectionViewModel = TabCollectionViewModel(tabCollection: TabCollection(tabs: [Tab(content: .newtab)]))
    let vc = FirePopoverWrapperViewController(fireViewModel: FireViewModel(), tabCollectionViewModel: tabCollectionViewModel)
    vc.infoPresentedOnce = false

    vc.onDeinit {
        withExtendedLifetime(tabCollectionViewModel) {}
    }

    return vc._preview_hidingWindowControlsOnAppear()
}() }

@available(macOS 14.0, *)
#Preview("Info presented once", traits: .fixedLayout(width: 344, height: 650)) { {
    let tabCollectionViewModel = TabCollectionViewModel(tabCollection: TabCollection(tabs: [Tab(content: .newtab)]))
    let vc = FirePopoverWrapperViewController(fireViewModel: FireViewModel(), tabCollectionViewModel: tabCollectionViewModel)
    vc.infoPresentedOnce = true

    vc.onDeinit {
        withExtendedLifetime(tabCollectionViewModel) {}
    }

    return vc._preview_hidingWindowControlsOnAppear()
}() }
