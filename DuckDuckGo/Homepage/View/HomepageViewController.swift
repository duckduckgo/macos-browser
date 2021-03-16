//
//  HomepageViewController.swift
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
import Combine

class HomepageViewController: NSViewController {

    enum Constants {
        static let maxNumberOfFavorites = 10
    }

    @IBOutlet weak var collectionView: NSCollectionView!

    private let tabCollectionViewModel: TabCollectionViewModel
    private var bookmarkManager: BookmarkManager
    private var topFavorites: [Bookmark]? {
        didSet {
            collectionView.reloadData()
        }
    }

    private var bookmarkListCancellable: AnyCancellable?

    required init?(coder: NSCoder) {
        fatalError("HomepageViewController: Bad initializer")
    }

    init?(coder: NSCoder, tabCollectionViewModel: TabCollectionViewModel, bookmarkManager: BookmarkManager) {
        self.tabCollectionViewModel = tabCollectionViewModel
        self.bookmarkManager = bookmarkManager

        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let nib = NSNib(nibNamed: "HomepageCollectionViewItem", bundle: nil)
        collectionView.register(nib, forItemWithIdentifier: HomepageCollectionViewItem.identifier)

        subscribeToBookmarkList()
    }

    private func subscribeToBookmarkList() {
        bookmarkListCancellable = bookmarkManager.listPublisher
            .receive(on: DispatchQueue.main)
            .dropFirst()
            .sink { [weak self] bookmarkList in
                self?.updateFavourites(from: bookmarkList)
            }
    }

    private func updateFavourites(from bookmarkList: BookmarkList) {
        topFavorites = Array(bookmarkList.bookmarks()
            .filter { $0.isFavorite }
            .prefix(Constants.maxNumberOfFavorites))
    }

    // MARK: - Add/Edit Favorite Popover

    private func showAddEditController(for bookmark: Bookmark? = nil) {
        // swiftlint:disable force_cast
        let windowController = NSStoryboard.homepage.instantiateController(withIdentifier: "AddEditFavoriteWindowController") as! NSWindowController
        // swiftlint:enable force_cast

        guard let window = windowController.window as? AddEditFavoriteWindow else {
            assertionFailure("HomepageViewController: Failed to present AddEditFavoriteWindowController")
            return
        }

        guard let screen = window.screen else {
            assertionFailure("HomepageViewController: No screen")
            return
        }

        if let bookmark = bookmark {
            window.addEditFavoriteViewController.edit(bookmark: bookmark)
        }

        let windowFrame = NSRect(x: screen.frame.size.width / 2.0 - AddEditFavoriteWindow.Size.width / 2.0,
                                 y: screen.frame.size.height / 2.0 - AddEditFavoriteWindow.Size.height / 2.0,
                                 width: AddEditFavoriteWindow.Size.width,
                                 height: AddEditFavoriteWindow.Size.height)

        view.window?.addChildWindow(window, ordered: .above)
        window.setFrame(windowFrame, display: true)
        window.makeKey()
    }

}

extension HomepageViewController: NSCollectionViewDataSource, NSCollectionViewDelegate {

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let topFavorites = topFavorites else { return 0 }

        if topFavorites.count < Constants.maxNumberOfFavorites {
            // + Adding button
            return topFavorites.count + 1
        } else {
            return topFavorites.count
        }
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        // swiftlint:disable force_cast
        let item = collectionView.makeItem(withIdentifier: HomepageCollectionViewItem.identifier,
                                           for: indexPath) as! HomepageCollectionViewItem
        // swiftlint:enable force_cast

        guard let topFavorites = topFavorites else {
            assertionFailure("HomepageViewController: No favorites to display")
            return item
        }

        guard indexPath.item < topFavorites.count else {
            item.setAddFavourite()
            return item
        }

        item.set(bookmark: topFavorites[indexPath.item])
        item.delegate = self
        return item
    }

    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        collectionView.deselectAll(self)

        guard let topFavorites = topFavorites else {
            assertionFailure("HomepageViewController: No favorites to display")
            return
        }

        guard let index = indexPaths.first?.item else {
            return
        }

        guard index < topFavorites.count else {
            showAddEditController()
            return
        }

        let favorite = topFavorites[index]
        tabCollectionViewModel.selectedTabViewModel?.tab.update(url: favorite.url, userEntered: false)
    }

 }

 extension HomepageViewController: NSCollectionViewDelegateFlowLayout {

     func collectionView(_ collectionView: NSCollectionView,
                         layout collectionViewLayout: NSCollectionViewLayout,
                         sizeForItemAt indexPath: IndexPath) -> NSSize {
        return NSSize(width: HomepageCollectionViewItem.Size.width, height: HomepageCollectionViewItem.Size.height)
     }

 }

extension HomepageViewController: HomepageCollectionViewItemDelegate {

    func homepageCollectionViewItemOpenInNewTabAction(_ homepageCollectionViewItem: HomepageCollectionViewItem) {
        if let indexPath = collectionView.indexPath(for: homepageCollectionViewItem),
           let favorite = topFavorites?[indexPath.item] {
            let tab = Tab(url: favorite.url, shouldLoadInBackground: true)
            tabCollectionViewModel.append(tab: tab, selected: false)
        }
    }

    func homepageCollectionViewItemOpenInNewWindowAction(_ homepageCollectionViewItem: HomepageCollectionViewItem) {
        if let indexPath = collectionView.indexPath(for: homepageCollectionViewItem),
           let favorite = topFavorites?[indexPath.item] {
            WindowsManager.openNewWindow(with: favorite.url)
        }
    }

    func homepageCollectionViewItemEditAction(_ homepageCollectionViewItem: HomepageCollectionViewItem) {
        if let indexPath = collectionView.indexPath(for: homepageCollectionViewItem),
           let favorite = topFavorites?[indexPath.item] {
            showAddEditController(for: favorite)
        }
    }

    func homepageCollectionViewItemRemoveAction(_ homepageCollectionViewItem: HomepageCollectionViewItem) {
        if let indexPath = collectionView.indexPath(for: homepageCollectionViewItem),
           let favorite = topFavorites?[indexPath.item] {
            bookmarkManager.remove(bookmark: favorite)
        }
    }

}

fileprivate extension NSStoryboard {

    static let homepage = NSStoryboard(name: "Homepage", bundle: .main)

}
