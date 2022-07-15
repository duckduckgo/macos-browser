//
//  BookmarksBarViewController.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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
import AppKit
import Combine
import os.log

final class BookmarksBarViewController: NSViewController {

    @IBOutlet private var bookmarksBarCollectionView: NSCollectionView!
    @IBOutlet private var clippedItemsIndicator: NSButton!

    private let bookmarkManager = LocalBookmarkManager.shared
    private let viewModel = BookmarksBarViewModel(bookmarkManager: LocalBookmarkManager.shared)
    private let tabCollectionViewModel: TabCollectionViewModel
    private var cancellables = Set<AnyCancellable>()
    
    fileprivate var clipThreshold: CGFloat {
        let viewWidthWithoutClipIndicator = view.frame.width - clippedItemsIndicator.frame.minX
        return view.frame.width - viewWidthWithoutClipIndicator - 3
    }
    
    init?(coder: NSCoder, tabCollectionViewModel: TabCollectionViewModel) {
        self.tabCollectionViewModel = tabCollectionViewModel
        super.init(coder: coder)
    }
    
    required init?(coder: NSCoder) {
        fatalError("TabBarViewController: Bad initializer")
    }
    
    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        viewModel.delegate = self

        let nib = NSNib(nibNamed: "BookmarksBarCollectionViewItem", bundle: .main)
        bookmarksBarCollectionView.register(nib, forItemWithIdentifier: BookmarksBarCollectionViewItem.identifier)
        
        bookmarksBarCollectionView.registerForDraggedTypes([.string, .URL])
        bookmarksBarCollectionView.setDraggingSourceOperationMask(.copy, forLocal: true)
        
        bookmarksBarCollectionView.delegate = viewModel
        bookmarksBarCollectionView.dataSource = viewModel
        bookmarksBarCollectionView.collectionViewLayout = createBookmarksBarCollectionViewLayout()
        
        view.postsFrameChangedNotifications = true
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(frameChangeNotification),
                                               name: NSView.frameDidChangeNotification,
                                               object: view)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(refreshFavicons),
                                               name: .faviconCacheUpdated,
                                               object: nil)
        
        subscribeToViewModel()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        clipOrRestoreBookmarksBarItems()
    }
    
    private func createCenteredLayout(centered: Bool) -> NSCollectionLayoutSection {
        let widths = viewModel.bookmarksBarItems.map { item in
            return viewModel.cachedWidth(buttonTitle: item.title)
        }

        let cellSizes = widths.map { CGSize(width: $0, height: 28) }
        
        let group = NSCollectionLayoutGroup.horizontallyCentered(cellSizes: cellSizes, centered: centered)
        let section = NSCollectionLayoutSection(group: group)

        return section
    }
    
    func createBookmarksBarCollectionViewLayout() -> NSCollectionViewLayout {
        return NSCollectionViewCompositionalLayout { [unowned self] _, _ in
            if viewModel.clippedItems.isEmpty {
                return createCenteredLayout(centered: true)
            } else {
                return createCenteredLayout(centered: false)
            }
        }
    }

    private func subscribeToViewModel() {
        viewModel.$clippedItems.receive(on: RunLoop.main).sink { [weak self] list in
            guard let self = self else { return }
            self.refreshClippedIndicator()
        }.store(in: &cancellables)
    }
    
    @objc
    private func frameChangeNotification() {
        clipOrRestoreBookmarksBarItems()
        refreshClippedIndicator()
    }
    
    private func refreshClippedIndicator() {
        self.clippedItemsIndicator.isHidden = viewModel.clippedItems.isEmpty
    }
    
    private func clipOrRestoreBookmarksBarItems() {
        guard !viewModel.bookmarksBarItems.isEmpty else {
            return
        }
        
        let lastIndexPath = IndexPath(item: viewModel.bookmarksBarItems.count - 1, section: 0)

        if viewModel.bookmarksBarItemsTotalWidth >= clipThreshold {
            if viewModel.clipLastBarItem() {
                self.bookmarksBarCollectionView.deleteItems(at: Set([lastIndexPath]))
            }
        } else if let nextRestorableClippedItem = viewModel.clippedItems.first {
            while true {
                if !restoreNextClippedItemToBookmarksBarIfPossible(item: nextRestorableClippedItem) {
                    break
                }
            }
            
            self.bookmarksBarCollectionView.reloadData()
        }
    }
    
    private func restoreNextClippedItemToBookmarksBarIfPossible(item: BookmarkViewModel) -> Bool {
        let widthOfRestorableItem = viewModel.cachedWidth(buttonTitle: item.entity.title)
        let newMaximumWidth = viewModel.bookmarksBarItemsTotalWidth + 10 + widthOfRestorableItem

        if newMaximumWidth < clipThreshold {
            return viewModel.restoreLastClippedItem()
        }
        
        return false
    }
    
    @objc
    private func refreshFavicons() {
        bookmarksBarCollectionView.reloadData()
    }

    @IBAction
    private func clippedItemsIndicatorClicked(_ sender: NSButton) {
        let menu = viewModel.buildClippedItemsMenu()
        let location = NSPoint(x: 0, y: sender.frame.height + 5)

        menu.popUp(positioning: nil, at: location, in: sender)
    }
    
}

extension BookmarksBarViewController: BookmarksBarViewModelDelegate {
    
    // swiftlint:disable:next cyclomatic_complexity
    func bookmarksBarViewModelReceived(action: BookmarksBarViewModel.BookmarksBarItemAction, for item: BookmarksBarCollectionViewItem) {
        guard let indexPath = bookmarksBarCollectionView.indexPath(for: item) else {
            assertionFailure("Failed to look up index path for clicked item")
            return
        }
        
        guard let entity = bookmarkManager.list?.topLevelEntities[indexPath.item] else {
            assertionFailure("Failed to get entity for clicked item")
            return
        }
        
        if let bookmark = entity as? Bookmark {
            switch action {
            case .openInNewTab:
                tabCollectionViewModel.appendNewTab(with: .url(bookmark.url), selected: true)
            case .openInBackgroundTab:
                tabCollectionViewModel.appendNewTab(with: .url(bookmark.url), selected: false)
            case .openInNewWindow:
                WindowsManager.openNewWindow(with: bookmark.url)
            case .clickItem:
                WindowControllersManager.shared.show(url: bookmark.url)
            case .toggleFavorite:                
                bookmark.isFavorite = !bookmark.isFavorite
                bookmarkManager.update(bookmark: bookmark)
            case .copyURL:
                break
            case .deleteEntity:
                bookmarkManager.remove(bookmark: bookmark)
            }
        } else if let folder = entity as? BookmarkFolder {
            switch action {
            case .clickItem:
                let childEntities = folder.children
                let viewModels = childEntities.map { BookmarkViewModel(entity: $0) }
                let menuItems = viewModel.bookmarksTreeMenuItems(from: viewModels, topLevel: true)
                let menu = bookmarkFolderMenu(items: menuItems)
                menu.popUp(positioning: nil, at: CGPoint(x: 0, y: item.view.frame.minY - 7), in: item.view)
            case .deleteEntity:
                bookmarkManager.remove(folder: folder)
            default:
                assertionFailure("Received unexpected action for bookmark folder")
            }
        } else {
            assertionFailure("Failed to cast entity for clicked item")
        }
    }
    
    func bookmarksBarViewModelWidthForContainer() -> CGFloat {
        return clipThreshold
    }
    
    func bookmarksBarViewModelReloadedData() {
        bookmarksBarCollectionView.reloadData()
    }
    
    private func bookmarkFolderMenu(items: [NSMenuItem]) -> NSMenu {
        let menu = NSMenu()
        
        if items.isEmpty {
            menu.items = [NSMenuItem(title: "Empty", action: nil, target: nil, keyEquivalent: "")]
        } else {
            menu.items = items
        }
        
        return menu
    }
    
}
