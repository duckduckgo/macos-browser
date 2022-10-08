//
//  BookmarkPopoverViewController.swift
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

protocol BookmarkPopoverViewControllerDelegate: AnyObject {

    func popoverShouldClose(_ bookmarkPopoverViewController: BookmarkPopoverViewController)

}

final class BookmarkPopoverViewController: NSViewController {

    static let favoriteImage = NSImage(named: "Favorite")
    static let favoriteFilledImage = NSImage(named: "FavoriteFilled")

    weak var delegate: BookmarkPopoverViewControllerDelegate?

    @IBOutlet weak var textField: NSTextField!
    @IBOutlet weak var favoriteButton: NSButton!
    @IBOutlet weak var folderPickerPopUpButton: NSPopUpButton!
    
    private var folderPickerSelectionCancellable: AnyCancellable?

    let bookmarkManager: BookmarkManager = LocalBookmarkManager.shared
    var bookmark: Bookmark? {
        didSet {
            if isViewLoaded {
                updateSubviews()
            }
        }
    }

    private var appearanceCancellable: AnyCancellable?

    override func viewDidLoad() {
        super.viewDidLoad()

        appearanceCancellable = view.subscribeForAppApperanceUpdates()
        textField.delegate = self
        
        folderPickerSelectionCancellable = folderPickerPopUpButton.selectionPublisher.dropFirst().sink { [weak self] index in
            guard let self = self,
                  let bookmark = self.bookmark,
                  let menuItem = self.folderPickerPopUpButton.item(at: index) else { return }
            
            let folder = menuItem.representedObject as? BookmarkFolder
            self.bookmarkManager.add(bookmark: bookmark, to: folder, completion: { _ in })
        }
    }

    override func viewWillAppear() {
        super.viewWillAppear()

        updateSubviews()
        refreshFolderPicker()
    }

    @IBAction func removeButtonAction(_ sender: NSButton) {
        guard let bookmark = bookmark else { return }
        bookmarkManager.remove(bookmark: bookmark)
        
        delegate?.popoverShouldClose(self)
    }

    @IBAction func doneButtonAction(_ sender: NSButton) {
        delegate?.popoverShouldClose(self)
    }
    
    @IBAction func favoritesButtonAction(_ sender: Any) {
        guard let bookmark = bookmark else { return }
        bookmark.isFavorite = !bookmark.isFavorite
        self.bookmark = bookmark

        bookmarkManager.update(bookmark: bookmark)
    }

    private func updateSubviews() {
        guard let bookmark = bookmark else {
            textField.stringValue = ""
            favoriteButton.image = Self.favoriteImage
            favoriteButton.title = UserText.addToFavorites
            return
        }

        if textField.stringValue != bookmark.title {
            textField.stringValue = bookmark.title
        }

        favoriteButton.image = bookmark.isFavorite ? Self.favoriteFilledImage : Self.favoriteImage
        favoriteButton.title = "  \(bookmark.isFavorite ? UserText.removeFromFavorites : UserText.addToFavorites)"
    }
    
    private func refreshFolderPicker() {
        guard let list = bookmarkManager.list else {
            assertionFailure("Tried to refresh bookmark folder picker, but couldn't get bookmark list")
            return
        }

        let bookmarksMenuItem = NSMenuItem(title: "Bookmarks", action: nil, target: nil, keyEquivalent: "")
        bookmarksMenuItem.image = NSImage(named: "Folder")

        let topLevelFolders = list.topLevelEntities.compactMap { $0 as? BookmarkFolder }
        var folderMenuItems = [NSMenuItem]()
        
        folderMenuItems.append(bookmarksMenuItem)
        folderMenuItems.append(.separator())
        folderMenuItems.append(contentsOf: createMenuItems(for: topLevelFolders))
                               
        folderPickerPopUpButton.menu?.items = folderMenuItems
        
        let selectedFolderMenuItem = folderMenuItems.first(where: { menuItem in
            guard let folder = menuItem.representedObject as? BookmarkFolder else {
                return false
            }
            
            return folder.id == bookmark?.parentFolderUUID
        })
        
        folderPickerPopUpButton.select(selectedFolderMenuItem ?? bookmarksMenuItem)
    }
    
    private func createMenuItems(for bookmarkFolders: [BookmarkFolder], level: Int = 0) -> [NSMenuItem] {
        let viewModels = bookmarkFolders.map(BookmarkViewModel.init(entity:))
        var menuItems = [NSMenuItem]()
        
        for viewModel in viewModels {
            let menuItem = NSMenuItem(bookmarkViewModel: viewModel)
            menuItem.indentationLevel = level
            menuItems.append(menuItem)
            
            if let folder = viewModel.entity as? BookmarkFolder, !folder.children.isEmpty {
                let childFolders = folder.children.compactMap { $0 as? BookmarkFolder }
                menuItems.append(contentsOf: createMenuItems(for: childFolders, level: level + 1))
            }
        }
        
        return menuItems
    }
    
}

extension BookmarkPopoverViewController: NSTextFieldDelegate {

    func controlTextDidChange(_ obj: Notification) {
        guard let bookmark = bookmark else { return }
        bookmark.title = textField.stringValue
        self.bookmark = bookmark

        bookmarkManager.update(bookmark: bookmark)
    }

}
