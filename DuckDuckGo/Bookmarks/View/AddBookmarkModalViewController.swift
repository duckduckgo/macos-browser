//
//  AddBookmarkModalViewController.swift
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

import AppKit
import Combine

protocol AddBookmarkModalViewControllerDelegate: AnyObject {

    func addBookmarkViewController(_ viewController: AddBookmarkModalViewController, addedBookmarkWithTitle title: String, url: URL)
    func addBookmarkViewController(_ viewController: AddBookmarkModalViewController, saved bookmark: Bookmark, newURL: URL)

}

final class AddBookmarkModalViewController: NSViewController {

    struct WebsiteInfo {
        let url: URL
        let title: String?

        init?(_ tab: Tab) {
            guard case let .url(url) = tab.content else {
                return nil
            }
            self.url = url
            self.title = tab.title
        }
    }

    enum Constants {
        static let storyboardName = "Bookmarks"
        static let identifier = "AddBookmarkModalViewController"
    }

    static func create() -> AddBookmarkModalViewController {
        let storyboard = NSStoryboard(name: Constants.storyboardName, bundle: nil)
        return storyboard.instantiateController(identifier: Constants.identifier)
    }

    var currentTabWebsite: WebsiteInfo? {
        didSet {
            if isViewLoaded {
                updateWithCurrentTabWebsite()
            }
        }
    }

    @IBOutlet var titleTextField: NSTextField!
    @IBOutlet var bookmarkTitleTextField: NSTextField!
    @IBOutlet var urlTextField: NSTextField!
    @IBOutlet var addButton: NSButton!

    private var hasValidInput: Bool {
        guard let url = urlTextField.stringValue.url else { return false }

        if originalBookmark != nil {
            return !bookmarkTitleTextField.stringValue.isEmpty && url.isValid
        } else {
            let isBookmarked = LocalBookmarkManager.shared.isUrlBookmarked(url: url)
            let isInputValid = !bookmarkTitleTextField.stringValue.isEmpty && url.isValid && !isBookmarked

            return isInputValid
        }
    }

    weak var delegate: AddBookmarkModalViewControllerDelegate?
    
    private var originalBookmark: Bookmark?

    override func viewDidLoad() {
        super.viewDidLoad()
        updateWithCurrentTabWebsite()
        updateWithExistingBookmark()
        updateAddButton()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        applyModalWindowStyleIfNeeded()
    }
    
    func edit(bookmark: Bookmark) {
        self.originalBookmark = bookmark
    }

    @IBAction private func cancel(_ sender: NSButton) {
        dismiss()
    }

    @IBAction private func addBookmark(_ sender: NSButton) {
        guard let url = urlTextField.stringValue.url else {
            return
        }
        
        if let bookmark = originalBookmark {
            bookmark.title = bookmarkTitleTextField.stringValue
            delegate?.addBookmarkViewController(self, saved: bookmark, newURL: url)
        } else {
            delegate?.addBookmarkViewController(self, addedBookmarkWithTitle: bookmarkTitleTextField.stringValue, url: url)
        }

        dismiss()
    }

    private func updateAddButton() {
        addButton.isEnabled = hasValidInput
    }

    private func updateWithCurrentTabWebsite() {
        if let website = currentTabWebsite, !LocalBookmarkManager.shared.isUrlBookmarked(url: website.url) {
            bookmarkTitleTextField.stringValue = website.title ?? ""
            urlTextField.stringValue = website.url.absoluteString
        }

        updateAddButton()
    }
    
    private func updateWithExistingBookmark() {
        if let originalBookmark = originalBookmark {
            titleTextField.stringValue = UserText.updateBookmark
            bookmarkTitleTextField.stringValue = originalBookmark.title
            urlTextField.stringValue = originalBookmark.url.absoluteString
            
            addButton.title = UserText.save
        }
    }

}

extension AddBookmarkModalViewController: NSTextFieldDelegate {

    func controlTextDidChange(_ notification: Notification) {
        updateAddButton()
    }

}
