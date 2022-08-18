//
//  PasteboardFolder.swift
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

struct PasteboardFolder: Hashable {

    struct Key {
        static let id = "id"
        static let name = "name"
    }

    let id: String
    let name: String

    init(id: String, name: String) {
        self.id = id
        self.name = name
    }

    // MARK: - Pasteboard Restoration

    init?(dictionary: PasteboardAttributes) {
        guard let id = dictionary[Key.id], let name = dictionary[Key.name] else {
            return nil
        }

        self.init(id: id, name: name)
    }

    init?(pasteboardItem: NSPasteboardItem) {
        let type = FolderPasteboardWriter.folderUTIInternalType

        guard pasteboardItem.types.contains(type),
              let dictionary = pasteboardItem.propertyList(forType: type) as? PasteboardAttributes else { return nil }

        self.init(dictionary: dictionary)
    }

    static func pasteboardFolders(with pasteboard: NSPasteboard) -> Set<PasteboardFolder>? {
        guard let items = pasteboard.pasteboardItems else {
            return nil
        }

        let folders = items.compactMap(PasteboardFolder.init(pasteboardItem:))
        return folders.isEmpty ? nil : Set(folders)
    }

    // MARK: - Dictionary Representations

    var internalDictionaryRepresentation: PasteboardAttributes {
        return [
            Key.id: id,
            Key.name: name
        ]
    }
}

@objc final class FolderPasteboardWriter: NSObject, NSPasteboardWriting {

    static let folderUTIInternal = "com.duckduckgo.folder.internal"
    static let folderUTIInternalType = NSPasteboard.PasteboardType(rawValue: folderUTIInternal)

    var pasteboardFolder: PasteboardFolder {
        return PasteboardFolder(id: folderID, name: folderName)
    }

    var internalDictionary: PasteboardAttributes {
        return pasteboardFolder.internalDictionaryRepresentation
    }

    private let folderID: String
    private let folderName: String

    init(folder: BookmarkFolder) {
        self.folderID = folder.id.uuidString
        self.folderName = folder.title
    }

    // MARK: - NSPasteboardWriting

    func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        return [FolderPasteboardWriter.folderUTIInternalType]
    }

    func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        switch type {
        case .string:
            return folderName
        case FolderPasteboardWriter.folderUTIInternalType:
            return internalDictionary
        default:
            return nil
        }
    }

}
