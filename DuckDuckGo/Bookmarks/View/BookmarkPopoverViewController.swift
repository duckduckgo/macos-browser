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

protocol BookmarkPopoverViewControllerDelegate: AnyObject {

    func popoverShouldClose(_ bookmarkPopoverViewController: BookmarkPopoverViewController)

}

class BookmarkPopoverViewController: NSViewController {

    static let favoriteImage = NSImage(named: "Favorite")
    static let favoriteFilledImage = NSImage(named: "FavoriteFilled")

    weak var delegate: BookmarkPopoverViewControllerDelegate?

    @IBOutlet weak var textField: NSTextField!
    @IBOutlet weak var favoriteButton: NSButton!

    let bookmarksManager: BookmarksManager = LocalBookmarksManager.shared
    var bookmark: Bookmark? {
        didSet {
            if isViewLoaded {
                updateSubviews()
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        textField.delegate = self
    }

    override func viewWillAppear() {
        super.viewWillAppear()

        updateSubviews()
    }

    @IBAction func removeButtonAction(_ sender: NSButton) {
        guard let bookmark = bookmark else { return }
        bookmarksManager.remove(bookmark: bookmark)
        
        delegate?.popoverShouldClose(self)
    }

    @IBAction func doneButtonAction(_ sender: NSButton) {
        delegate?.popoverShouldClose(self)
    }
    
    @IBAction func favoritesButtonAction(_ sender: Any) {
        guard var bookmark = bookmark else { return }
        bookmark.isFavorite = !bookmark.isFavorite
        self.bookmark = bookmark

        bookmarksManager.update(bookmark: bookmark)
    }

    func updateSubviews() {
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
}

extension BookmarkPopoverViewController: NSTextFieldDelegate {

    func controlTextDidChange(_ obj: Notification) {
        guard var bookmark = bookmark else { return }
        bookmark.title = textField.stringValue
        self.bookmark = bookmark

        bookmarksManager.update(bookmark: bookmark)
    }

}
