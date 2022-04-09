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

}

final class AddBookmarkModalViewController: NSViewController {

    struct WebsiteInfo {
        let url: URL
        let title: String?

        init?(_ tab: Tab) {
            guard case .url(let url) = tab.content else {
                return nil
            }
            self.url = url
            title = tab.title
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
        updateWithCurrentTabWebsite()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        applyModalWindowStyleIfNeeded()
    }

    @IBAction
    private func cancel(_: NSButton) {
        dismiss()
    }

    @IBAction
    private func addBookmark(_: NSButton) {
        guard let url = urlTextField.stringValue.url else {
            return
        }

        delegate?.addBookmarkViewController(self, addedBookmarkWithTitle: titleTextField.stringValue, url: url)
        dismiss()
    }

    private func updateAddButton() {
        addButton.isEnabled = hasValidInput
    }

    private func updateWithCurrentTabWebsite() {
        if let website = currentTabWebsite, !LocalBookmarkManager.shared.isUrlBookmarked(url: website.url) {
            titleTextField.stringValue = website.title ?? ""
            urlTextField.stringValue = website.url.absoluteString
        }
        updateAddButton()
    }

}

extension AddBookmarkModalViewController: NSTextFieldDelegate {

    func controlTextDidChange(_: Notification) {
        updateAddButton()
    }

}
