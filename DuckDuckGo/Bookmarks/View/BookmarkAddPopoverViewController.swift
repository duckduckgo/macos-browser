//
//  BookmarkAddPopoverViewController.swift
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

final class BookmarkAddPopoverViewController: NSViewController {

    static let favoriteImage = NSImage(named: "Favorite")
    static let favoriteFilledImage = NSImage(named: "FavoriteFilled")

    weak var container: BookmarkPopoverContainer?

    @IBOutlet weak var textField: NSTextField!
    @IBOutlet weak var favoriteButton: NSButton!
    @IBOutlet weak var folderPickerPopUpButton: NSPopUpButton!
    @IBOutlet weak var folderAddButton: NSButton!

    private var folderPickerSelectionCancellable: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()

    var bookmarkManager: BookmarkManager {
        guard let container else {
            return LocalBookmarkManager.shared
        }
        return container.bookmarkManager
    }

    var bookmark: Bookmark? {
        get {
            container?.bookmark
        }
        set {
            container?.bookmark = newValue
            if isViewLoaded {
                updateSubviews()
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupPickerSelectionCancellable()
        setupListPublisher()
        folderAddButton.setButtonType(.onOff)
        textField.delegate = self
    }

    private func setupListPublisher() {
        bookmarkManager.listPublisher.receive(on: DispatchQueue.main).sink { [weak self] _ in
            guard let url = self?.bookmark?.url else { return }
            self?.bookmark = self?.bookmarkManager.getBookmark(forUrl: url)
            self?.refreshFolderPicker()
        }.store(in: &cancellables)
    }

    private func setupPickerSelectionCancellable() {
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
        container?.popoverShouldClose()
    }

    @IBAction func doneButtonAction(_ sender: NSButton) {
        container?.popoverShouldClose()
    }

    @IBAction func favoritesButtonAction(_ sender: Any) {
        guard let bookmark = bookmark else { return }
        bookmark.isFavorite = !bookmark.isFavorite
        self.bookmark = bookmark

        bookmarkManager.update(bookmark: bookmark)
    }

    @IBAction func addFolder(_ sender: Any) {
        container?.showFolderAddView()
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
        guard let menuItems = container?.getMenuItems() else {
            return
        }
        folderPickerPopUpButton.menu?.items = menuItems

        let selectedFolderMenuItem = menuItems.first(where: { menuItem in
            guard let folder = menuItem.representedObject as? BookmarkFolder else {
                return false
            }
            return folder.id == bookmark?.parentFolderUUID
        })

        folderPickerPopUpButton.select(selectedFolderMenuItem ?? menuItems.first)
    }

}

extension BookmarkAddPopoverViewController: NSTextFieldDelegate {

    func controlTextDidChange(_ obj: Notification) {
        guard let bookmark = bookmark else { return }
        bookmark.title = textField.stringValue
        self.bookmark = bookmark

        bookmarkManager.update(bookmark: bookmark)
    }

}
