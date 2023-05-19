//
//  AddEditFavoriteViewController.swift
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

final class AddEditFavoriteViewController: NSViewController {

    @IBOutlet weak var headerTextField: NSTextField!
    @IBOutlet weak var titleInputTextField: NSTextField!
    @IBOutlet weak var urlInputTextField: NSTextField!
    @IBOutlet weak var confirmButton: NSButton!

    private var bookmarkManager: BookmarkManager = LocalBookmarkManager.shared
    private var originalBookmark: Bookmark?

    private var cancellables = Set<AnyCancellable>()

    override func viewDidLoad() {
        super.viewDidLoad()

        updateConfirmButton()
        subscribeToInputTextFields()
    }

    @IBAction func cancelAction(_ sender: NSButton) {
        view.window?.close()
    }

    @IBAction func saveAction(_ sender: NSButton) {

        func update(bookmark: Bookmark, newTitle: String, newUrl: URL? = nil) {
            let bookmark = bookmark
            bookmark.isFavorite = true
            bookmark.title = newTitle
            bookmarkManager.update(bookmark: bookmark)

            if let newUrl = newUrl, newUrl != bookmark.url {
                bookmarkManager.updateUrl(of: bookmark, to: newUrl)
            }
        }

        guard isInputValid, let newUrl = urlInputTextField.stringValue.url else {
            assertionFailure("Not valid input")
            return
        }

        let newTitle = titleInputTextField.stringValue
        if let bookmark = originalBookmark {
            // Editing
            update(bookmark: bookmark, newTitle: newTitle, newUrl: newUrl)
        } else {
            // Saving
            if let bookmark = bookmarkManager.getBookmark(for: newUrl) {
                update(bookmark: bookmark, newTitle: newTitle)
            } else {
                bookmarkManager.makeBookmark(for: newUrl, title: newTitle, isFavorite: true)
            }
        }
        view.window?.close()
    }

    func edit(bookmark: Bookmark) {
        originalBookmark = bookmark
        titleInputTextField.stringValue = bookmark.title
        urlInputTextField.stringValue = bookmark.url.absoluteString

        headerTextField.stringValue = UserText.editFavorite
        confirmButton.title = UserText.save

        updateConfirmButton()
    }

    private func subscribeToInputTextFields() {
        NotificationCenter.default
            .publisher(for: NSControl.textDidChangeNotification, object: titleInputTextField)
            .sink { [weak self] _ in self?.updateConfirmButton() }
            .store(in: &cancellables)
        NotificationCenter.default
            .publisher(for: NSControl.textDidChangeNotification, object: urlInputTextField)
            .sink { [weak self] _ in self?.updateConfirmButton() }
            .store(in: &cancellables)
    }

    private var isInputValid: Bool {
        guard let url = urlInputTextField.stringValue.url else { return false }
        let isBookmarked = bookmarkManager.isUrlBookmarked(url: url)
        let isInputValid = !titleInputTextField.stringValue.isEmpty &&
            url.isValid &&
            (!isBookmarked || url == originalBookmark?.url)
        return isInputValid
    }

    private func updateConfirmButton() {
        confirmButton.isEnabled = isInputValid
    }

}
