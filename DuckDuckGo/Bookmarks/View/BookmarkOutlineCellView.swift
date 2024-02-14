//
//  BookmarkOutlineCellView.swift
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
import Foundation

final class BookmarkOutlineCellView: NSTableCellView {

    private lazy var faviconImageView = NSImageView()
    private lazy var titleLabel = NSTextField(string: "Bookmark/Folder")
    private lazy var countLabel = NSTextField(string: "42")

    init(identifier: NSUserInterfaceItemIdentifier) {
        super.init(frame: .zero)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("\(type(of: self)): Bad initializer")
    }

    private func setupUI() {
        addSubview(faviconImageView)
        addSubview(titleLabel)
        addSubview(countLabel)

        faviconImageView.translatesAutoresizingMaskIntoConstraints = false
        faviconImageView.image = .bookmarkDefaultFavicon
        faviconImageView.imageScaling = .scaleProportionallyDown
        faviconImageView.wantsLayer = true
        faviconImageView.layer?.cornerRadius = 2.0

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.isEditable = false
        titleLabel.isBordered = false
        titleLabel.isSelectable = false
        titleLabel.drawsBackground = false
        titleLabel.font = .systemFont(ofSize: 13)
        titleLabel.textColor = .controlTextColor
        titleLabel.lineBreakMode = .byTruncatingTail

        countLabel.translatesAutoresizingMaskIntoConstraints = false
        countLabel.isEditable = false
        countLabel.isBordered = false
        countLabel.isSelectable = false
        countLabel.drawsBackground = false
        countLabel.font = .preferredFont(forTextStyle: .body)
        countLabel.alignment = .right
        countLabel.textColor = .blackWhite60
        countLabel.lineBreakMode = .byClipping

        setupLayout()
    }

    private func setupLayout() {
        faviconImageView.heightAnchor.constraint(equalToConstant: 16).isActive = true
        faviconImageView.widthAnchor.constraint(equalToConstant: 16).isActive = true
        faviconImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 5).isActive = true
        faviconImageView.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        faviconImageView.setContentHuggingPriority(NSLayoutConstraint.Priority(rawValue: 251), for: .horizontal)
        faviconImageView.setContentHuggingPriority(NSLayoutConstraint.Priority(rawValue: 251), for: .vertical)

        titleLabel.leadingAnchor.constraint(equalTo: faviconImageView.trailingAnchor, constant: 10).isActive = true
        bottomAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6).isActive = true
        titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 6).isActive = true
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleLabel.setContentHuggingPriority(.defaultHigh, for: .vertical)
        titleLabel.setContentHuggingPriority(.init(rawValue: 200), for: .horizontal)

        countLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor).isActive = true
        countLabel.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 5).isActive = true
        trailingAnchor.constraint(equalTo: countLabel.trailingAnchor).isActive = true
        countLabel.setContentHuggingPriority(.defaultHigh, for: .vertical)
        countLabel.setContentHuggingPriority(.required, for: .horizontal)
    }

    func update(from bookmark: Bookmark) {
        faviconImageView.image = bookmark.favicon(.small) ?? .bookmarkDefaultFavicon
        titleLabel.stringValue = bookmark.title
        countLabel.stringValue = ""
    }

    func update(from folder: BookmarkFolder) {
        faviconImageView.image = .folder
        titleLabel.stringValue = folder.title

        let totalChildBookmarks = folder.totalChildBookmarks
        if totalChildBookmarks > 0 {
            countLabel.stringValue = String(totalChildBookmarks)
        } else {
            countLabel.stringValue = ""
        }
    }

    func update(from pseudoFolder: PseudoFolder) {
        faviconImageView.image = pseudoFolder.icon
        titleLabel.stringValue = pseudoFolder.name
        countLabel.stringValue = pseudoFolder.count > 0 ? String(pseudoFolder.count) : ""
    }

}

#if DEBUG
@available(macOS 14.0, *)
#Preview {
    BookmarkOutlineCellView.PreviewView()
}

extension BookmarkOutlineCellView {
    final class PreviewView: NSView {

        init() {
            super.init(frame: .zero)
            wantsLayer = true
            layer!.backgroundColor = NSColor.white.cgColor

            translatesAutoresizingMaskIntoConstraints = true

            let cells = [
                BookmarkOutlineCellView(identifier: .init("id")),
                BookmarkOutlineCellView(identifier: .init("id")),
                BookmarkOutlineCellView(identifier: .init("id")),
                BookmarkOutlineCellView(identifier: .init("id")),
                BookmarkOutlineCellView(identifier: .init("id")),
            ]

            let stackView = NSStackView(views: cells as [NSView])
            stackView.orientation = .vertical
            stackView.spacing = 1
            addAndLayout(stackView)

            cells[0].update(from: Bookmark(id: "1", url: "http://a.b", title: "DuckDuckGo", isFavorite: true))
            cells[1].update(from: BookmarkFolder(id: "2", title: "Bookmark Folder with a reasonably long name"))
            cells[2].update(from: BookmarkFolder(id: "2", title: "Bookmark Folder with 42 bookmark children", children: Array(repeating: Bookmark(id: "2", url: "http://a.b", title: "DuckDuckGo", isFavorite: true), count: 42)))
            PseudoFolder.favorites.count = 64
            cells[3].update(from: PseudoFolder.favorites)
            PseudoFolder.bookmarks.count = 256
            cells[4].update(from: PseudoFolder.bookmarks)

            widthAnchor.constraint(equalToConstant: 258).isActive = true
            heightAnchor.constraint(equalToConstant: CGFloat((28 + 1) * cells.count)).isActive = true
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

    }
}
#endif
