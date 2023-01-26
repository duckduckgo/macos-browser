//
//  AddFolderModalViewController.swift
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

protocol AddFolderModalViewControllerDelegate: AnyObject {

    func addFolderViewController(_ viewController: AddFolderModalViewController, addedFolderWith name: String)
    func addFolderViewController(_ viewController: AddFolderModalViewController, saved folder: BookmarkFolder)
    func addFolderViewControllerWillClose()

}

extension AddFolderModalViewControllerDelegate {
    func addFolderViewControllerWillClose() {}
}

final class AddFolderModalViewController: NSViewController {

    enum Constants {
        static let storyboardName = "Bookmarks"
        static let identifier = "AddFolderModalViewController"
    }

    static func create() -> AddFolderModalViewController {
        let storyboard = NSStoryboard(name: Constants.storyboardName, bundle: nil)
        return storyboard.instantiateController(identifier: Constants.identifier)
    }

    @IBOutlet var titleTextField: NSTextField!
    @IBOutlet var folderNameTextField: NSTextField!
    @IBOutlet var addButton: NSButton!

    weak var delegate: AddFolderModalViewControllerDelegate?

    private var originalFolder: BookmarkFolder?

    override func viewDidLoad() {
        super.viewDidLoad()
        updateInterface()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        applyModalWindowStyleIfNeeded()
    }

    func edit(folder: BookmarkFolder) {
        self.originalFolder = folder
    }

    private func updateInterface() {
        updateConfirmButton()

        if let folder = originalFolder {
            titleTextField.stringValue = UserText.renameFolder

            folderNameTextField.stringValue = folder.title
            addButton.title = UserText.save
            updateConfirmButton()
        } else {
            titleTextField.stringValue = UserText.newFolder
        }
    }

    @IBAction private func cancel(_ sender: NSButton) {
        delegate?.addFolderViewControllerWillClose()
        dismiss()
    }

    @IBAction private func addFolder(_ sender: NSButton) {
        guard !folderNameTextField.stringValue.isEmpty else { return }

        if let folder = originalFolder {
            folder.title = folderNameTextField.stringValue
            delegate?.addFolderViewController(self, saved: folder)
        } else {
            delegate?.addFolderViewController(self, addedFolderWith: folderNameTextField.stringValue)
        }

        delegate?.addFolderViewControllerWillClose()
        dismiss()
    }

    private func updateConfirmButton() {
        addButton.isEnabled = !folderNameTextField.stringValue.isEmpty
    }

}

extension AddFolderModalViewController: NSTextFieldDelegate {

    func controlTextDidChange(_ notification: Notification) {
        updateConfirmButton()
    }

}
