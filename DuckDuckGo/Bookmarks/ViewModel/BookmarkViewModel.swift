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
            return favicon
        } else if entity is BookmarkFolder {
            return NSImage(named: "Folder")
        } else {
            return nil
        }
    }

    // MARK: - Representing Color and Character

    static var representingColors = [
        NSColor.bookmarkRepresentingColor1,
        NSColor.bookmarkRepresentingColor2,
        NSColor.bookmarkRepresentingColor3,
        NSColor.bookmarkRepresentingColor4,
        NSColor.bookmarkRepresentingColor5
    ]

    // Representing color is a color shown as a background of home page item when
    // the bookmark has no favicon
    var representingColor: NSColor {
        guard let bookmark = entity as? Bookmark else {
            preconditionFailure("\(#file): Attempted to provide representing color for non-Bookmark")
        }
        
        let index = bookmark.url.absoluteString.count % Self.representingColors.count
        return Self.representingColors[index]
    }

    // Representing character is on top of representing color
    var representingCharacter: String {
        guard let bookmark = entity as? Bookmark else {
            preconditionFailure("\(#file): Attempted to provide representing character for non-Bookmark")
        }

        return bookmark.url.host?.droppingWwwPrefix().first?.uppercased() ?? "-"
    }

}

fileprivate extension NSImage {

    static let favoriteFaviconImage = NSImage(named: "FavoriteFavicon")!

    func makeFavoriteOverlay() -> NSImage {
        let overlayImage = Self.favoriteFaviconImage

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
