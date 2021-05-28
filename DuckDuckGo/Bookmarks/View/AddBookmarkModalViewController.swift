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

    func addBookmarkViewController(_ viewController: AddBookmarkModalViewController, addedBookmarkWithTitle title: String, url: String)

}

final class AddBookmarkModalViewController: NSViewController {

    enum Constants {
        static let storyboardName = "Bookmarks"
        static let identifier = "AddBookmarkModalViewController"
    }

    static func create() -> AddBookmarkModalViewController {
        let storyboard = NSStoryboard(name: Constants.storyboardName, bundle: nil)
        return storyboard.instantiateController(identifier: Constants.identifier)
    }

    @IBOutlet var titleTextField: NSTextField!
    @IBOutlet var urlTextField: NSTextField!
    @IBOutlet var addButton: NSButton!

    private var hasValidInput: Bool {
        guard let url = urlTextField.stringValue.url else { return false }

        let isBookmarked = LocalBookmarkManager.shared.isUrlBookmarked(url: url)
        let isInputValid = !titleTextField.stringValue.isEmpty && url.isValid && !isBookmarked

        return isInputValid
    }

    weak var delegate: AddBookmarkModalViewControllerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        updateAddButton()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        applyModalWindowStyleIfNeeded()
    }

    @IBAction private func cancel(_ sender: NSButton) {
        dismiss()
    }

    @IBAction private func addBookmark(_ sender: NSButton) {
        delegate?.addBookmarkViewController(self, addedBookmarkWithTitle: titleTextField.stringValue, url: urlTextField.stringValue)
        dismiss()
    }

    private func updateAddButton() {
        addButton.isEnabled = hasValidInput
    }

}

extension AddBookmarkModalViewController: NSTextFieldDelegate {

    func controlTextDidChange(_ notification: Notification) {
        updateAddButton()
    }

}
