//
//  BookmarkAddFolderPopoverViewController.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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

final class BookmarkAddFolderPopoverViewController: NSViewController {

    weak var container: BookmarkPopoverContainer?
    var parentFolder: BookmarkFolder?

    @IBOutlet var folderNameTextField: NSTextField!
    @IBOutlet var folderPickerPopUpButton: NSPopUpButton!

    private var folderPickerSelectionCancellable: AnyCancellable?

    var bookmarkManager: BookmarkManager {
        guard let container else {
            assertionFailure("The container has does not have a BookmarkManager Instance, defaulting to the shared instance ")
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
        }
    }

    @IBAction private func cancel(_ sender: NSButton) {
        container?.showBookmarkAddView()
    }

    @IBAction private func save(_ sender: NSButton) {
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        folderNameTextField.delegate = self
        refreshFolderPicker()
    }

    private func refreshFolderPicker() {
        guard let menuItems = container?.bookmarksMenuItems else {
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

extension BookmarkAddFolderPopoverViewController: NSTextFieldDelegate {

    func controlTextDidChange(_ obj: Notification) {}

}
