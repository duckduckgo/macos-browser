//
//  NSPasteboardItemExtension.swift
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

extension NSPasteboardItem {

    var bookmarkEntityUUID: String? {
        if let bookmark = propertyList(forType: BookmarkPasteboardWriter.bookmarkUTIInternalType) as? PasteboardAttributes,
           let bookmarkID = bookmark[PasteboardBookmark.Key.id] {
            return bookmarkID
        }

        if let folder = propertyList(forType: FolderPasteboardWriter.folderUTIInternalType) as? PasteboardAttributes,
           let folderID = folder[PasteboardFolder.Key.id] {
            return folderID
        }

        return nil
    }

    func draggedWebViewValues() -> (title: String?, url: URL)? {
        guard let urlString = string(forType: .URL), let url = URL(string: urlString) else {
            return nil
        }

        // WKWebView pasteboard items include the name of the link under the `public.url-name` type.
        let name = string(forType: .urlName)
        return (title: name, url: url)
    }

}
