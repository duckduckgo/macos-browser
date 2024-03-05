//
//  BookmarkViewModel.swift
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

struct BookmarkViewModel {

    let entity: BaseBookmarkEntity

    var menuTitle: String {
        let title: String

        if let bookmark = entity as? Bookmark {
            title = bookmark.title
        } else if let folder = entity as? BookmarkFolder {
            title = folder.title
        } else {
            preconditionFailure("\(#file): Failed to case BaseBookmarkEntity to Bookmark or Folder")
        }

        if title.count <= MainMenu.Constants.maxTitleLength {
            return title
        } else {
            return String(title.truncated(length: MainMenu.Constants.maxTitleLength))
        }

    }

    var menuFavicon: NSImage? {
        if let bookmark = entity as? Bookmark {
            let favicon = bookmark.favicon(.small)?.copy() as? NSImage
            favicon?.size = NSSize.faviconSize

            return favicon ?? .bookmarkDefaultFavicon
        } else if entity is BookmarkFolder {
            return .folder
        } else {
            return nil
        }
    }

}

fileprivate extension NSImage {

    func makeFavoriteOverlay() -> NSImage {
        let overlayImage = NSImage.favoriteFavicon

        let newImage = NSImage(size: size)
        newImage.lockFocus()

        var newImageRect: CGRect = .zero
        newImageRect.size = newImage.size

        var overlayImageRect: CGRect = .zero
        overlayImageRect.size = overlayImage.size
        overlayImageRect.origin = CGPoint(x: newImage.size.width - overlayImage.size.width, y: newImage.size.height - overlayImage.size.height)

        draw(in: newImageRect)
        overlayImage.draw(in: overlayImageRect)

        newImage.unlockFocus()
        return newImage
    }

}
