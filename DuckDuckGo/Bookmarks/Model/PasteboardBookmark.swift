//
//  PasteboardBookmark.swift
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

import Foundation
import AppKit

typealias PasteboardAttributes = [String: String]

struct PasteboardBookmark: Hashable {

    struct Key {
        static let id = "id"
        static let url = "URL"
        static let title = "title"
    }

    let id: String
    let url: String
    let title: String

    init(id: String, url: String, title: String) {
        self.id = id
        self.url = url
        self.title = title
    }

    // MARK: - Pasteboard Restoration

    init?(dictionary: PasteboardAttributes) {
        guard let id = dictionary[Key.id], let url = dictionary[Key.url], let title = dictionary[Key.title] else {
            return nil
        }

        self.init(id: id, url: url, title: title)
    }

    init?(pasteboardItem: NSPasteboardItem) {
        let type = BookmarkPasteboardWriter.bookmarkUTIInternalType

        guard pasteboardItem.types.contains(type),
              let dictionary = pasteboardItem.propertyList(forType: type) as? PasteboardAttributes else { return nil }

        self.init(dictionary: dictionary)
    }

    static func pasteboardBookmarks(with pasteboardItems: [NSPasteboardItem]?) -> Set<PasteboardBookmark>? {
        guard let items = pasteboardItems else {
            return nil
        }

        let bookmarks = items.compactMap(PasteboardBookmark.init(pasteboardItem:))
        return bookmarks.isEmpty ? nil : Set(bookmarks)
    }

    // MARK: - Dictionary Representations

    var internalDictionaryRepresentation: PasteboardAttributes {
        return [
            Key.id: id,
            Key.url: url,
            Key.title: title
        ]
    }

}

extension BaseBookmarkEntity: PasteboardWriting {

    var pasteboardWriter: NSPasteboardWriting {
        if let bookmark = self as? Bookmark {
            return BookmarkPasteboardWriter(bookmark: bookmark)
        } else if let folder = self as? BookmarkFolder {
            return FolderPasteboardWriter(folder: folder)
        } else {
            preconditionFailure()
        }
    }

}

@objc final class BookmarkPasteboardWriter: NSObject, NSPasteboardWriting {

    static let bookmarkUTIInternal = "com.duckduckgo.bookmark.internal"
    static let bookmarkUTIInternalType = NSPasteboard.PasteboardType(rawValue: bookmarkUTIInternal)

    var pasteboardBookmark: PasteboardBookmark {
        return PasteboardBookmark(id: bookmarkID, url: bookmarkURL, title: bookmarkTitle)
    }

    var internalDictionary: PasteboardAttributes {
        return pasteboardBookmark.internalDictionaryRepresentation
    }

    private let bookmarkID: String
    private let bookmarkURL: String
    private let bookmarkTitle: String

    init(bookmark: Bookmark) {
        self.bookmarkID = bookmark.id
        self.bookmarkURL = bookmark.url
        self.bookmarkTitle = bookmark.title
    }

    // MARK: - NSPasteboardWriting

    func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        return [.URL, .string, BookmarkPasteboardWriter.bookmarkUTIInternalType]
    }

    func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        switch type {
        case .string, .URL:
            return bookmarkURL
        case BookmarkPasteboardWriter.bookmarkUTIInternalType:
            return internalDictionary
        default:
            return nil
        }
    }

}
