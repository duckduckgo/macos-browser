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

import Foundation

struct BookmarkViewModel {

    let bookmark: Bookmark

    static let maxMenuTitleLength = 55
    var menuTitle: String {
        if bookmark.title.count <= Self.maxMenuTitleLength {
            return bookmark.title
        } else {
            let suffix = "..."
            return String(bookmark.title.prefix(Self.maxMenuTitleLength - suffix.count)) + suffix
        }

    }

    var menuFavicon: NSImage? {
        // Once we have bookmark folders
        // bookmark.isFavorite ? bookmark.favicon?.makeFavoriteOverlay() : bookmark.favicon

        let favicon = bookmark.favicon?.copy() as? NSImage
        favicon?.size = NSSize.faviconSize
        return favicon
    }

    // MARK: - Representing Color and Character

    static var representingColors = [
        NSColor(named: "BookmarkRepresentingColor1")!,
        NSColor(named: "BookmarkRepresentingColor2")!,
        NSColor(named: "BookmarkRepresentingColor3")!,
        NSColor(named: "BookmarkRepresentingColor4")!,
        NSColor(named: "BookmarkRepresentingColor5")!
    ]

    // Representing color is a color shown as a background of homepage item when
    // the bookmark has no favicon
    var representingColor: NSColor {
        let index = bookmark.url.absoluteString.count % Self.representingColors.count
        return Self.representingColors[index]
    }

    // Representing character is on top of representing color
    var representingCharacter: String {
        return bookmark.url.host?.dropWWW().first?.uppercased() ?? "-"
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
