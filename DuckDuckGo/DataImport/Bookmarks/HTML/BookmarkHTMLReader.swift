//
//  BookmarkHTMLReader.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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
import BrowserServicesKit

struct HTMLImportedBookmarks {
    let source: BookmarkImportSource?
    let bookmarks: ImportedBookmarks
}

final class BookmarkHTMLReader {

    struct ImportError: DataImportError {
        // !! do not change the order
        // cases 2,3 and 6 are reserved for removed errors
        enum OperationType: Int {
            case parseXml = 0
            case validationBody = 1
            case proceedToTopLevelFolder = 4
            case readFolder = 5
            case unknown = 7
        }

        var action: DataImportAction { .bookmarks }
        let type: OperationType
        let underlyingError: Error?

        var errorType: DataImport.ErrorType { .dataCorrupted }
    }

    private var currentOperationType: ImportError.OperationType = .parseXml
    private let otherBookmarksFolderTitle: String

    init(bookmarksFileURL: URL, otherBookmarksFolderTitle: String = UserText.otherBookmarksImportedFolderTitle) {
        self.bookmarksFileURL = bookmarksFileURL
        self.otherBookmarksFolderTitle = otherBookmarksFolderTitle
    }

    func readBookmarks() -> DataImportResult<HTMLImportedBookmarks> {
        do {
            let result = try reallyReadBookmarks()
            return .success(result)
        } catch let error as ImportError {
            return .failure(error)
        } catch {
            return .failure(ImportError(type: currentOperationType, underlyingError: error))
        }
    }

    private func reallyReadBookmarks() throws -> HTMLImportedBookmarks {
        //
        // Bookmarks HTML is not a valid HTML and needs to be fixed before parsing, hence `.documentTidyHTML`.
        // This, however, has a side effect of wrapping any `<p></p>` tags (otherwise irrelevant to
        // the bookmarks structure) in `<dd></dd>` tags, that need to be handled while parsing.
        // More info:
        //  * https://social.msdn.microsoft.com/Forums/en-US/42547a38-7f65-432e-a40b-821b99aebdbb/intelligent-xmlhtml-parsing-firefoxnetscape-bookmarkshtml-format
        //  * https://www.w3schools.com/TAgs/tag_dd.asp
        //
        currentOperationType = .parseXml
        let document = try XMLDocument(contentsOf: bookmarksFileURL, options: [.documentTidyHTML])
        currentOperationType = .unknown // further operations should throw ImportError

        var cursor = try validateHTMLBookmarksDocument(document)
        let importSource = try determineImportSource(&cursor)

        let firstFolder = try readFolder(cursor)

        var other = [ImportedBookmarks.BookmarkOrFolder]()
        if importSource == .duckduckgoWebKit {
            if firstFolder.name.isEmpty {
                other.append(contentsOf: firstFolder.children ?? [])
            } else {
                other.append(firstFolder)
            }
        }

        while cursor != nil {
            let itemType: XMLNode.BookmarkItemType?
            if importSource?.supportsSafariBookmarksHTMLFormat == true {
                let initialCursor = cursor
                itemType = findNextItemInSafariFormat(&cursor) ?? {
                    // fallback to non-safari format
                    cursor = initialCursor
                    return findNextItem(&cursor)
                }()
            } else {
                itemType = findNextItem(&cursor)
            }

            guard let itemType else { break }

            let items = try readItem(itemType, at: cursor)
            other.append(contentsOf: items)
        }

        let bookmarkBar: ImportedBookmarks.BookmarkOrFolder
        if importSource == .duckduckgoWebKit {
            // DDG does not have a "Bookmarks Bar" so let's fake it with an empty folder that will not be imported
            bookmarkBar = .folder(name: "", children: [])
        } else {
            bookmarkBar = firstFolder
        }

        let otherBookmarks = ImportedBookmarks.BookmarkOrFolder.folder(name: otherBookmarksFolderTitle, children: other)
        let allBookmarks = ImportedBookmarks(topLevelFolders: .init(bookmarkBar: bookmarkBar, otherBookmarks: otherBookmarks, syncedBookmarks: nil))
        let result = HTMLImportedBookmarks(source: importSource, bookmarks: allBookmarks)

        return result
    }

    // MARK: - Private

    private func determineImportSource(_ cursor: inout XMLNode?) throws -> BookmarkImportSource? {
        let isInSafariFormat = try findTopLevelFolderNameNode(&cursor)

        if cursor?.rootDocument?.isDDGBookmarksDocument == true {
            return .duckduckgoWebKit
        }

        if isInSafariFormat {
            return .thirdPartyBrowser(.safari)
        }

        return nil
    }

    private func validateHTMLBookmarksDocument(_ document: XMLDocument) throws -> XMLNode? {
        let root = document.rootElement()
        guard let body = root?.childIfExists(at: 1) else { throw ImportError(type: .validationBody, underlyingError: nil) }
        // get /html/body/*[0]
        let cursor = body.childIfExists(at: 0)

        return cursor
    }

    private func findTopLevelFolderNameNode(_ cursor: inout XMLNode?) throws -> Bool {
        var isInSafariFormat = false

        rootLoop: while cursor != nil {
            switch cursor?.htmlTag {
            case .dl:
                let originalCursorValue = cursor
                cursor = cursor?.childIfExists(at: 0)
                dlLoop: while cursor != nil {
                    switch cursor?.htmlTag {
                    case .dd:
                        if cursor?.childIfExists(at: 0)?.htmlTag == .h3 {
                            cursor = cursor?.childIfExists(at: 0)
                            break dlLoop
                        }
                        cursor = cursor?.nextSibling
                    case .dt:
                        // There is no "top-level" folder, and the first item
                        // in the bookmarks file is a regular bookmark, not a folder.
                        // This is specific to iOS and MacOS DuckDuckGo apps.
                        cursor = originalCursorValue
                        isInSafariFormat = true
                        break dlLoop
                    default:
                        throw ImportError(type: .proceedToTopLevelFolder, underlyingError: nil)
                    }
                }
                break rootLoop
            case .h3:
                isInSafariFormat = true
                break rootLoop
            default:
                cursor = cursor?.nextSibling
            }
        }

        return isInSafariFormat
    }

    private func findNextItem(_ cursor: inout XMLNode?) -> XMLNode.BookmarkItemType? {
        var itemType: XMLNode.BookmarkItemType?
        cursor = cursor?.parent?.nextSibling

        while cursor != nil && itemType == nil {
            itemType = cursor?.itemType(inSafariFormat: false)
            switch itemType {
            case .some:
                cursor = cursor?.childIfExists(at: 0)
            case .none:
                cursor = cursor?.nextSibling
            }
        }

        return itemType
    }

    private func findNextItemInSafariFormat(_ cursor: inout XMLNode?) -> XMLNode.BookmarkItemType? {
        var itemType: XMLNode.BookmarkItemType?

        while cursor != nil && itemType == nil {
            cursor = cursor?.nextSibling
            itemType = cursor?.itemType(inSafariFormat: true)
        }

        return itemType
    }

    private func readItem(_ item: XMLNode.BookmarkItemType, at cursor: XMLNode?) throws -> [ImportedBookmarks.BookmarkOrFolder] {
        switch item {
        case .bookmark:
            return readBookmark(cursor).map { [$0] } ?? []
        case .folder:
            return [try readFolder(cursor)]
        case .safariTopLevelBookmarks:
            return try readFolderContents(cursor)
        }
    }

    private func readFolder(_ node: XMLNode?) throws -> ImportedBookmarks.BookmarkOrFolder {
        var cursor = node

        var folderName: String = ""
        if cursor?.htmlTag == .h3, let name = cursor?.stringValue {
            folderName = name
            cursor = cursor?.nextSibling
        }

        guard cursor?.htmlTag == .dl else { throw ImportError(type: .readFolder, underlyingError: nil) }

        let children = try readFolderContents(cursor)
        return .folder(name: folderName, children: children)
    }

    private func readFolderContents(_ node: XMLNode?) throws -> [ImportedBookmarks.BookmarkOrFolder] {
        var cursor = node
        cursor = cursor?.childIfExists(at: 0)

        var children = [ImportedBookmarks.BookmarkOrFolder]()

        while cursor != nil {
            let firstChild = cursor?.childIfExists(at: 0)
            switch (cursor?.htmlTag, firstChild?.htmlTag) {
            case (.dd, .h3):
                children.append(try readFolder(firstChild))
            case (.dt, .a):
                if let bookmark = readBookmark(firstChild) {
                    children.append(bookmark)
                }
            default:
                break
            }

            cursor = cursor?.nextSibling
        }

        return children
    }

    private func readBookmark(_ node: XMLNode?) -> ImportedBookmarks.BookmarkOrFolder? {
        return node?.bookmark
    }

    private let bookmarksFileURL: URL
}

private extension BookmarkImportSource {
    var supportsSafariBookmarksHTMLFormat: Bool {
        switch self {
        case .duckduckgoWebKit,
             .thirdPartyBrowser(.safari),
             .thirdPartyBrowser(.safariTechnologyPreview):
            return true

        case .thirdPartyBrowser(.brave),
             .thirdPartyBrowser(.chrome),
             .thirdPartyBrowser(.chromium),
             .thirdPartyBrowser(.coccoc),
             .thirdPartyBrowser(.edge),
             .thirdPartyBrowser(.firefox),
             .thirdPartyBrowser(.opera),
             .thirdPartyBrowser(.operaGX),
             .thirdPartyBrowser(.tor),
             .thirdPartyBrowser(.vivaldi),
             .thirdPartyBrowser(.yandex),
             .thirdPartyBrowser(.bitwarden),
             .thirdPartyBrowser(.onePassword8),
             .thirdPartyBrowser(.onePassword7),
             .thirdPartyBrowser(.lastPass),
             .thirdPartyBrowser(.csv),
             .thirdPartyBrowser(.bookmarksHTML):
            return false
        }
    }
}

private extension XMLDocument {
    enum Const {
        static let ddgNamespacePrefix = "duckduckgo"
        static let ddgNamespaceValue = "https://duckduckgo.com/bookmarks"
    }

    var isDDGBookmarksDocument: Bool {
        rootElement()?.namespace(forPrefix: Const.ddgNamespacePrefix)?.stringValue == Const.ddgNamespaceValue
    }
}

private extension XMLNode {

    enum Const {
        static let idAttributeName = "id"
        static let readingListID = "com.apple.ReadingList"
    }

    enum HTMLTag: String {
        /// Bookmarks document title
        case h1
        /// Bookmark folder name
        case h3
        /// Bookmark folder contents
        case dl
        /// Individual bookmark
        case dt
        /// Tag added by XMLDocument while tidying up bookmarks HTML
        case dd
        /// Contains bookmark URL and name
        case a
    }

    var htmlTag: HTMLTag? {
        guard let name = name else {
            return nil
        }
        return .init(rawValue: name)
    }

    enum BookmarkItemType {
        case bookmark, folder, safariTopLevelBookmarks
    }

    func itemType(inSafariFormat isInSafariFormat: Bool) -> BookmarkItemType? {
        if isInSafariFormat {
            switch htmlTag {
            case .h3:
                return .folder
            case .dt:
                return .bookmark
            case .dl where childIfExists(at: 0)?.childIfExists(at: 0)?.htmlTag == .a:
                return .safariTopLevelBookmarks
            default:
                return nil
            }
        } else {
            switch (htmlTag, childIfExists(at: 0)?.htmlTag) {
            case (.dd, .h3):
                return .folder
            case (.dt, .a):
                return .bookmark
            default:
                return nil
            }
        }
    }

    var text: String? {
        stringValue?.trimmingWhitespace()
    }

    var bookmark: ImportedBookmarks.BookmarkOrFolder? {
        guard htmlTag == .a,
              let name = text,
              let element = self as? XMLElement else { return nil }

        if element.stringValue == "---" && element.attribute(forName: "href")?.stringValue == "http://bookmark.placeholder.url/" {
            // vivaldi separator markup
            return nil
        }

        return .bookmark(
            name: name,
            urlString: element.attribute(forName: "href")?.stringValue,
            isDDGFavorite: element.attribute(forName: "duckduckgo:favorite")?.stringValue == "true"
        )
    }
}
