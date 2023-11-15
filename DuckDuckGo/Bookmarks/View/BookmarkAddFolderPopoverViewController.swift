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
    @IBOutlet var addFolderButton: NSButton!

    private var cancellables = Set<AnyCancellable>()

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

    var selectedFolderMenuItem: NSMenuItem? {
        let selectedFolderMenuItem = folderPickerPopUpButton.menu?.items.first(where: { menuItem in
            guard let folder = menuItem.representedObject as? BookmarkFolder else {
                return false
            }
            return folder.id == bookmark?.parentFolderUUID

        })
        return selectedFolderMenuItem
    }

    @IBAction private func cancel(_ sender: NSButton) {
        container?.showBookmarkAddView()
    }

    @IBAction private func save(_ sender: NSButton) {
        let name = folderNameTextField.stringValue
        let selectedFolder = selectedFolderMenuItem?.representedObject as? BookmarkFolder
        guard let currentBookmark = self.bookmark else { return }

        // Create the folder and then move the bookmark to it
        bookmarkManager.makeFolder(for: name, parent: selectedFolder, completion: { folder in
            self.bookmarkManager.move(objectUUIDs: [currentBookmark.id],
                                      toIndex: 1,
                                      withinParentFolder: .parent(uuid: folder.id),
                                      completion: { _ in })
            self.container?.showBookmarkAddView()
        })

    }

    override func viewDidLoad() {
        super.viewDidLoad()
        folderNameTextField.delegate = self
        addFolderButton.isEnabled = false
        refreshFolderPicker()
    }

    private func refreshFolderPicker() {
        guard let menuItems = container?.getMenuItems() else {
            return
        }
        folderPickerPopUpButton.menu?.items = menuItems
        folderPickerPopUpButton.select(selectedFolderMenuItem ?? menuItems.first)
    }

}

extension BookmarkAddFolderPopoverViewController: NSTextFieldDelegate {

    func controlTextDidChange(_ obj: Notification) {
        addFolderButton.isEnabled = folderNameTextField.stringValue != ""
    }

}
