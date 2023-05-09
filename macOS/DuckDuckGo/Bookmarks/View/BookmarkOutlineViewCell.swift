//
//  BookmarkOutlineViewCell.swift
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

final class BookmarkOutlineViewCell: NSTableCellView {

    static let identifier = NSUserInterfaceItemIdentifier("BookmarkOutlineViewCell")
    static let nib = NSNib(nibNamed: "BookmarkOutlineViewCell", bundle: Bundle.main)

    private static let defaultBookmarkFavicon = NSImage(named: "BookmarkDefaultFavicon")

    @IBOutlet var faviconImageView: NSImageView! {
        didSet {
            faviconImageView.wantsLayer = true
            faviconImageView.layer?.cornerRadius = 2.0
        }
    }

    @IBOutlet var titleLabel: NSTextField!
    @IBOutlet var countLabel: NSTextField!

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {}

    func update(from bookmark: Bookmark) {
        faviconImageView.image = bookmark.favicon(.small) ?? Self.defaultBookmarkFavicon
        titleLabel.stringValue = bookmark.title
        countLabel.stringValue = ""
    }

    func update(from folder: BookmarkFolder) {
        faviconImageView.image = NSImage(named: "Folder")
        titleLabel.stringValue = folder.title
        countLabel.stringValue = ""

        let totalChildBookmarks = folder.totalChildBookmarks
        if totalChildBookmarks > 0 {
            countLabel.stringValue = "\(totalChildBookmarks)"
        } else {
            countLabel.stringValue = ""
        }
    }

    func update(from pseudoFolder: PseudoFolder) {
        faviconImageView.image = pseudoFolder.icon
        titleLabel.stringValue = pseudoFolder.name
        countLabel.stringValue = pseudoFolder.count > 0 ? "\(pseudoFolder.count)" : ""
    }
}
