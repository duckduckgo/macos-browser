//
//  FirePopoverViewController.swift
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

import Cocoa

final class FirePopoverViewController: NSViewController {

    let fireViewModel: FireViewModel
    let tabCollectionViewModel: TabCollectionViewModel

    @IBOutlet weak var openDetailsButton: NSButton!
    @IBOutlet weak var closeDetailsButton: NSButton!
    @IBOutlet weak var detailsWrapperView: NSView!
    @IBOutlet weak var contentSizeConstraint: NSLayoutConstraint!
    @IBOutlet weak var collectionView: NSCollectionView!

    required init?(coder: NSCoder) {
        fatalError("FirePopoverViewController: Bad initializer")
    }

    init?(coder: NSCoder, fireViewModel: FireViewModel, tabCollectionViewModel: TabCollectionViewModel) {
        self.fireViewModel = fireViewModel
        self.tabCollectionViewModel = tabCollectionViewModel

        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        collectionView.delegate = self
        collectionView.dataSource = self
    }

    @IBAction func openDetailsButtonAction(_ sender: Any) {
        toggleDetails()
    }

    @IBAction func closeDetailsButtonAction(_ sender: Any) {
        toggleDetails()
    }

    @IBAction func clearButtonAction(_ sender: Any) {
        let timedPixel = TimedPixel(.burn())
        fireViewModel.fire.burnAll(tabCollectionViewModel: tabCollectionViewModel) { timedPixel.fire() }
    }

    @IBAction func cancelButtonAction(_ sender: Any) {

    }

    func toggleDetails() {
        let showDetails = detailsWrapperView.isHidden
        openDetailsButton.isHidden = showDetails
        detailsWrapperView.isHidden = !showDetails

        NSAnimationContext.runAnimationGroup { [weak self] context in
            context.duration = 1/3
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self?.contentSizeConstraint.animator().constant = showDetails ? 263 : 42
        }
    }

}

extension FirePopoverViewController: NSCollectionViewDataSource {

    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        return 2
    }

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return 3
    }

    static let itemIdentifier = NSUserInterfaceItemIdentifier(rawValue: "FirePopoverCollectionViewItem")

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: Self.itemIdentifier, for: indexPath)
        guard let _ = item as? FirePopoverCollectionViewItem else { return item }

        return item
    }

    static let headerIdentifier = NSUserInterfaceItemIdentifier(rawValue: "FirePopoverCollectionViewHeader")

    func collectionView(_ collectionView: NSCollectionView,
                        viewForSupplementaryElementOfKind kind: NSCollectionView.SupplementaryElementKind,
                        at indexPath: IndexPath) -> NSView {
        // swiftlint:disable force_cast
        let view = collectionView.makeSupplementaryView(ofKind: NSCollectionView.elementKindSectionHeader,
                                                        withIdentifier: Self.headerIdentifier,
                                                        for: indexPath) as! FirePopoverCollectionViewHeader
        // swiftlint:enable force_cast

        if indexPath.section == 0 {
            view.title.stringValue = "Fireproof Sites"
        } else {
            view.title.stringValue = "Clear These Sites"
        }

        return view
    }

}

extension FirePopoverViewController: NSCollectionViewDelegate {

}

extension FirePopoverViewController : NSCollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: NSCollectionView,
                        layout collectionViewLayout: NSCollectionViewLayout,
                        referenceSizeForHeaderInSection section: Int) -> NSSize {
        return NSSize(width: collectionView.bounds.width, height: 28)
    }

}
