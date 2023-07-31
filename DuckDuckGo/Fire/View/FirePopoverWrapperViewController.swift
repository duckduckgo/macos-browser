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

    @IBOutlet weak var infoView: NSView!
    @IBOutlet weak var popoverView: NSView!

    @UserDefaultsWrapper(key: .fireInfoPresentedOnce, defaultValue: false)
    var infoPresentedOnce: Bool

    private let fireViewModel: FireViewModel
    private weak var tabCollectionViewModel: TabCollectionViewModel?

    required init?(coder: NSCoder) {
        fatalError("FirePopoverWrapperViewController: Bad initializer")
    }

    init?(coder: NSCoder,
          fireViewModel: FireViewModel,
          tabCollectionViewModel: TabCollectionViewModel) {
        self.fireViewModel = fireViewModel
        self.tabCollectionViewModel = tabCollectionViewModel

        super.init(coder: coder)
    }

    @IBSegueAction func createFirePopoverViewController(_ coder: NSCoder) -> FirePopoverViewController? {
        guard let tabCollectionViewModel = tabCollectionViewModel else {
            assertionFailure("Attempted to display Fire Popover without an associated TabCollectionViewModel")
            return nil
        }

        let firePopoverViewController = FirePopoverViewController(coder: coder,
                                                                  fireViewModel: fireViewModel,
                                                                  tabCollectionViewModel: tabCollectionViewModel)
        firePopoverViewController?.delegate = self
        return firePopoverViewController
    }

    @IBSegueAction func createFireInfoViewController(_ coder: NSCoder) -> FireInfoViewController? {
        let fireInfoViewController = FireInfoViewController(coder: coder)
        fireInfoViewController?.delegate = self
        return fireInfoViewController

    }

    override func viewDidLoad() {
        super.viewDidLoad()

        hideInfoContainerViewIfNeeded()
    }

    private func hideInfoContainerViewIfNeeded() {
        guard let tabCollectionViewModel else {
            return
        }

        let infoIsVisible = !infoPresentedOnce && !tabCollectionViewModel.isBurner
        infoView.isHidden = !infoIsVisible
        popoverView.isHidden = infoIsVisible
    }

}

extension FirePopoverWrapperViewController: FireInfoViewControllerDelegate {

    func fireInfoViewControllerDidConfirm(_ fireInfoViewController: FireInfoViewController) {
        infoPresentedOnce = true
        hideInfoContainerViewIfNeeded()
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
