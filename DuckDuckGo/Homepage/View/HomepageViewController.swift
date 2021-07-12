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

final class HomepageViewController: NSViewController {

    // Temporary placeholders that are displayed when user has no favorites
    // Should be removed when the search element of the homepage is implemented
    static let favoritePlaceholders: [Bookmark] = [
        Bookmark(id: UUID(),
                 url: URL.duckDuckGo,
                 title: "Search",
                 favicon: NSImage(named: "HomepageSearch"),
                 isFavorite: true),
        Bookmark(id: UUID(),
                 url: URL.duckDuckGoEmail,
                 title: "Email",
                 favicon: NSImage(named: "HomepageEmail"),
                 isFavorite: true),
        Bookmark(id: UUID(),
                 url: URL(string: "https://spreadprivacy.com/")!,
                 title: "Spread Privacy",
                 favicon: NSImage(named: "HomepageSpreadPrivacy"),
                 isFavorite: true)
    ]

    enum Constants {
        static let maxNumberOfFavorites = 10
    }

    private var defaultBrowserPromptView = DefaultBrowserPromptView.createFromNib()
    @IBOutlet weak var collectionView: NSCollectionView!

    @UserDefaultsWrapper(key: .defaultBrowserDismissed, defaultValue: false)
    var defaultBrowserPromptDismissed: Bool

    private let tabCollectionViewModel: TabCollectionViewModel
    private var bookmarkManager: BookmarkManager
    private var topFavorites: [Bookmark]? {
        didSet {
            areFavoritesPlaceholders = topFavorites == Self.favoritePlaceholders

            collectionView.reloadData()
        }
    }
    private var areFavoritesPlaceholders = false

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

        layoutDefaultBrowserPromptView()
        (self.view as? HomepageBackgroundView)?.defaultBrowserPromptView = defaultBrowserPromptView
        let nib = NSNib(nibNamed: "HomepageCollectionViewItem", bundle: nil)
        collectionView.register(nib, forItemWithIdentifier: HomepageCollectionViewItem.identifier)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(displayDefaultBrowserPromptIfNeeded),
                                               name: NSApplication.didBecomeActiveNotification,
                                               object: nil)

        subscribeToBookmarkList()
    }

    override func viewWillAppear() {
        super.viewWillAppear()

        displayDefaultBrowserPromptIfNeeded()
    }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)

        view.window?.makeFirstResponder(nil)
    }

    func layoutDefaultBrowserPromptView() {
        defaultBrowserPromptView.delegate = self
        defaultBrowserPromptView.frame = NSRect(x: 0,
                                                y: self.view.bounds.height - defaultBrowserPromptView.frame.height,
                                                width: self.view.bounds.width,
                                                height: defaultBrowserPromptView.frame.height)
        defaultBrowserPromptView.autoresizingMask = [.width, .minYMargin]
        defaultBrowserPromptView.translatesAutoresizingMaskIntoConstraints = true
        self.view.addSubview(defaultBrowserPromptView)
    }

    @objc
    private func displayDefaultBrowserPromptIfNeeded() {
        defaultBrowserPromptView.isHidden = DefaultBrowserPreferences.isDefault || defaultBrowserPromptDismissed
    }

    private func subscribeToBookmarkList() {
        bookmarkListCancellable = bookmarkManager.listPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] bookmarkList in
                self?.updateFavourites(from: bookmarkList)
            }
    }

    private func updateFavourites(from bookmarkList: BookmarkList?) {
        guard let favorites = bookmarkList?.bookmarks().filter({ $0.isFavorite }) else {
            return
        }

        if favorites.isEmpty {
            topFavorites = Self.favoritePlaceholders
        } else {
            topFavorites = Array(favorites
                                    .prefix(Constants.maxNumberOfFavorites)
                                    .reversed())
        }
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

        let windowFrame = NSRect(x: screen.frame.origin.x + screen.frame.size.width / 2.0 - AddEditFavoriteWindow.Size.width / 2.0,
                                 y: screen.frame.origin.y + screen.frame.size.height / 2.0 - AddEditFavoriteWindow.Size.height / 2.0,
                                 width: AddEditFavoriteWindow.Size.width,
                                 height: AddEditFavoriteWindow.Size.height)

        view.window?.addChildWindow(window, ordered: .above)
        window.setFrame(windowFrame, display: true)
        window.makeKey()
    }

}

extension HomepageViewController: DefaultBrowserPromptViewDelegate {

    func defaultBrowserPromptViewDismissed(_ view: DefaultBrowserPromptView) {
        defaultBrowserPromptDismissed = true
        displayDefaultBrowserPromptIfNeeded()
    }

    func defaultBrowserPromptViewRequestedDefaultBrowserPrompt(_ view: DefaultBrowserPromptView) {
        DefaultBrowserPreferences.becomeDefault()
        displayDefaultBrowserPromptIfNeeded()
        Pixel.fire(.browserMadeDefault)
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

        item.set(bookmarkViewModel: BookmarkViewModel(entity: topFavorites[indexPath.item]), isPlaceholder: areFavoritesPlaceholders)
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

        Pixel.fire(.navigation(kind: .favorite, source: .newTab))

        let favorite = topFavorites[index]
        tabCollectionViewModel.selectedTabViewModel?.tab.update(url: favorite.url, userEntered: true)
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
