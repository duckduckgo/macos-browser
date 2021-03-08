//
//  WebExtensionsViewController.swift
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

class WebExtensionsViewController: NSViewController {

    @IBOutlet weak var collectionView: NSCollectionView!
    let webExtensionsManager = WebExtensionsManager.shared

    override func viewDidLoad() {
        super.viewDidLoad()

        let nib = NSNib(nibNamed: "WebExtensionCollectionViewItem", bundle: nil)
        collectionView.register(nib, forItemWithIdentifier: WebExtensionCollectionViewItem.identifier)
    }

}

extension WebExtensionsViewController: NSCollectionViewDataSource, NSCollectionViewDelegate {

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return webExtensionsManager.webExtensions.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        // swiftlint:disable force_cast
        let item = collectionView.makeItem(withIdentifier: WebExtensionCollectionViewItem.identifier,
                                           for: indexPath) as! WebExtensionCollectionViewItem
        // swiftlint:enable force_cast
        let webExtension = webExtensionsManager.webExtensions[indexPath.item]

        item.set(webExtension: webExtension)
        return item
    }

    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        resetActiveWebExtensions()
    }

    func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {
        resetActiveWebExtensions()
    }

    private func resetActiveWebExtensions() {
        let activeExtensions = collectionView.selectionIndexPaths
            .map { webExtensionsManager.webExtensions[$0.item] }
        webExtensionsManager.activeExtensions = activeExtensions
    }

}

extension WebExtensionsViewController: NSCollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: NSCollectionView,
                        layout collectionViewLayout: NSCollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> NSSize {
        return NSSize(width: collectionView.frame.size.width, height: 72)
    }

}
