//
//  BookmarkDragDropManager.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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
import Common
import Foundation
import os.log

final class BookmarkDragDropManager {

    static let shared = BookmarkDragDropManager()

    static let draggedTypes: [NSPasteboard.PasteboardType] = [
        .string,
        .URL,
        BookmarkPasteboardWriter.bookmarkUTIInternalType,
        FolderPasteboardWriter.folderUTIInternalType
    ]

    private let bookmarkManager: BookmarkManager

    init(bookmarkManager: BookmarkManager = LocalBookmarkManager.shared) {
        self.bookmarkManager = bookmarkManager
    }

    func validateDrop(_ info: NSDraggingInfo, to destination: Any) -> NSDragOperation {
        let bookmarks = PasteboardBookmark.pasteboardBookmarks(with: info.draggingPasteboard.pasteboardItems)
        let folders = PasteboardFolder.pasteboardFolders(with: info.draggingPasteboard.pasteboardItems)

        let bookmarksDragOperation = bookmarks.flatMap { validateMove(for: $0, destination: destination) }
        let foldersDragOperation = folders.flatMap { validateMove(for: $0, destination: destination) }

        switch (bookmarksDragOperation, foldersDragOperation) {
        // If the dragged values contain both folders and bookmarks, only validate the move if all objects can be moved.
        case (true, true), (true, nil), (nil, true):
            return .move
        case (false, _), (_, false):
            return .none
        default:
            guard destination is BookmarkFolder || destination is PseudoFolder else { return .none }

            if info.draggingPasteboard.availableType(from: [.URL]) != nil {
                return .copy
            }

            if let string = info.draggingPasteboard.string(forType: .string),
                URL(trimmedAddressBarString: string.trimmingWhitespace()) != nil {
                return .copy
            }

            return .none
        }
    }

    private func validateMove(for draggedBookmarks: Set<PasteboardBookmark>, destination: Any) -> Bool? {
        guard !draggedBookmarks.isEmpty else { return nil }
        guard destination is BookmarkFolder || destination is PseudoFolder else { return false }

        return true
    }

    private func validateMove(for draggedFolders: Set<PasteboardFolder>, destination: Any) -> Bool? {
        guard !draggedFolders.isEmpty else { return nil }

        guard let destinationFolder = destination as? BookmarkFolder else {
            if destination as? PseudoFolder == .bookmarks {
                return true
            }
            return false
        }

        // Folders cannot be dragged onto themselves or any of their descendants:
        return draggedFolders.allSatisfy { folder in
            bookmarkManager.canMoveObjectWithUUID(objectUUID: folder.id, to: destinationFolder)
        }
    }

    @discardableResult
    @MainActor
    func acceptDrop(_ info: NSDraggingInfo, to destination: Any, at index: Int) -> Bool {
        defer {
            // prevent other drop targets accepting the dragged items twice
            info.draggingPasteboard.clearContents()
        }
        guard let draggedObjectIdentifiers = info.draggingPasteboard.pasteboardItems?.compactMap(\.bookmarkEntityUUID), !draggedObjectIdentifiers.isEmpty else {
            return createBookmarks(from: info.draggingPasteboard.pasteboardItems ?? [], in: destination, at: index, window: info.draggingDestinationWindow)
        }

        switch destination {
        case let folder as BookmarkFolder:
            if folder.id == PseudoFolder.bookmarks.id { fallthrough }

            let index = (index == -1 || index == NSNotFound) ? 0 : index
            let parent: ParentFolderType = (folder.id == PseudoFolder.bookmarks.id) ? .root : .parent(uuid: folder.id)
            bookmarkManager.move(objectUUIDs: draggedObjectIdentifiers, toIndex: index, withinParentFolder: parent) { error in
                if let error = error {
                    Logger.general.error("Failed to accept existing parent drop via outline view: \(error.localizedDescription)")
                }
            }

        case is PseudoFolder where (destination as? PseudoFolder) == .bookmarks:
            if index == -1 || index == NSNotFound {
                bookmarkManager.add(objectsWithUUIDs: draggedObjectIdentifiers, to: nil) { error in
                    if let error = error {
                        Logger.general.error("Failed to accept nil parent drop via outline view: \(error.localizedDescription)")
                    }
                }
            } else {
                bookmarkManager.move(objectUUIDs: draggedObjectIdentifiers, toIndex: index, withinParentFolder: .root) { error in
                    if let error = error {
                        Logger.general.error("Failed to accept nil parent drop via outline view: \(error.localizedDescription)")
                    }
                }
            }

        case let pseudoFolder as PseudoFolder where pseudoFolder == .favorites:
            if index == -1 || index == NSNotFound {
                bookmarkManager.update(objectsWithUUIDs: draggedObjectIdentifiers, update: { entity in
                    let bookmark = entity as? Bookmark
                    bookmark?.isFavorite = true
                }, completion: { error in
                    if let error = error {
                        Logger.general.error("Failed to update entities during drop via outline view: \(error.localizedDescription)")
                    }
                })
            } else {
                bookmarkManager.moveFavorites(with: draggedObjectIdentifiers, toIndex: index) { error in
                    if let error = error {
                        Logger.general.error("Failed to update entities during drop via outline view: \(error.localizedDescription)")
                    }
                }
            }

        default:
            assertionFailure("Unknown destination: \(destination)")
            return false
        }

        return true
    }

    @MainActor
    private func createBookmarks(from pasteboardItems: [NSPasteboardItem], in destination: Any, at index: Int, window: NSWindow?) -> Bool {
        var parent: BookmarkFolder?
        var isFavorite = false

        switch destination {
        case let pseudoFolder as PseudoFolder where pseudoFolder == .favorites:
            isFavorite = true
        case let pseudoFolder as PseudoFolder where pseudoFolder == .bookmarks:
            isFavorite = false

        case let folder as BookmarkFolder:
            parent = folder

        default:
            assertionFailure("Unknown destination: \(destination)")
            return false
        }

        var currentIndex = index
        for item in pasteboardItems {
            let url: URL
            let title: String
            func titleFromUrlDroppingSchemeIfNeeded(_ url: URL) -> String {
                let title = url.absoluteString
                // drop `http[s]://` from bookmark URL used as its title
                if let scheme = url.navigationalScheme, scheme.isHypertextScheme {
                    return title.dropping(prefix: scheme.separated())
                }
                return title
            }
            if let webViewItem = item.draggedWebViewValues() {
                url = webViewItem.url
                title = webViewItem.title ?? self.title(forTabWith: webViewItem.url, in: window) ?? titleFromUrlDroppingSchemeIfNeeded(url)
            } else if let draggedString = item.string(forType: .string),
                      let draggedURL = URL(trimmedAddressBarString: draggedString.trimmingWhitespace()) {
                url = draggedURL
                title = self.title(forTabWith: draggedURL, in: window) ?? titleFromUrlDroppingSchemeIfNeeded(url)
            } else {
                continue
            }

            self.bookmarkManager.makeBookmark(for: url, title: title, isFavorite: isFavorite, index: currentIndex, parent: parent)
            currentIndex += 1
        }

        return currentIndex > index
    }

    @MainActor
    private func title(forTabWith url: URL, in window: NSWindow?) -> String? {
        guard let mainViewController = window?.contentViewController as? MainViewController else { return nil }
        return mainViewController.tabCollectionViewModel.title(forTabWithURL: url)
    }

}
