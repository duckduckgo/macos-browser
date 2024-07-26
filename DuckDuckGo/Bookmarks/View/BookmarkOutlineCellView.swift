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

protocol BookmarkOutlineCellViewDelegate: AnyObject {
    func outlineCellViewRequestedMenu(_ cell: BookmarkOutlineCellView)
}

final class BookmarkOutlineCellView: NSTableCellView {

    private static let sizingCellIdentifier = NSUserInterfaceItemIdentifier("sizing")
    static let sizingCell: BookmarkOutlineCellView = {
        let cell = BookmarkOutlineCellView(identifier: BookmarkOutlineCellView.sizingCellIdentifier)
        cell.translatesAutoresizingMaskIntoConstraints = false
        return cell
    }()

    static let rowHeight: CGFloat = 28

    private lazy var faviconImageView = NSImageView()
    private lazy var titleLabel = NSTextField(string: "Bookmark/Folder")
    private var titleLabelToFaviconLeading: NSLayoutConstraint!
    private lazy var countLabel = NSTextField(string: "42")
    private lazy var urlLabel = NSTextField(string: "URL")
    private lazy var menuButton = NSButton(title: "", image: .settings, target: self, action: #selector(cellMenuButtonClicked))
    private lazy var favoriteImageView = NSImageView()

    var highlight = false {
        didSet {
            updateUI()
        }
    }
    var isInKeyWindow = true {
        didSet {
            updateUI()
        }
    }

    var shouldShowMenuButton = false

    weak var delegate: BookmarkOutlineCellViewDelegate?

    init(identifier: NSUserInterfaceItemIdentifier) {
        super.init(frame: .zero)
        self.identifier = identifier
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("\(type(of: self)): Bad initializer")
    }

    // MARK: - Private

    private func setupUI() {
        addSubview(faviconImageView)
        addSubview(titleLabel)
        addSubview(countLabel)
        addSubview(urlLabel)
        addSubview(menuButton)
        addSubview(favoriteImageView)

        faviconImageView.translatesAutoresizingMaskIntoConstraints = false
        faviconImageView.image = .bookmarkDefaultFavicon
        faviconImageView.imageScaling = .scaleProportionallyDown
        faviconImageView.wantsLayer = true
        faviconImageView.layer?.cornerRadius = 2.0
        faviconImageView.setAccessibilityIdentifier("BookmarkOutlineCellView.favIconImageView")

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

        urlLabel.translatesAutoresizingMaskIntoConstraints = false
        urlLabel.isEditable = false
        urlLabel.isBordered = false
        urlLabel.isSelectable = false
        urlLabel.drawsBackground = false
        urlLabel.font = .systemFont(ofSize: 13)
        urlLabel.textColor = .secondaryLabelColor
        urlLabel.lineBreakMode = .byTruncatingTail

        menuButton.translatesAutoresizingMaskIntoConstraints = false
        menuButton.contentTintColor = .button
        menuButton.imagePosition = .imageTrailing
        menuButton.isBordered = false
        menuButton.isHidden = true
        menuButton.sendAction(on: .leftMouseDown)

        favoriteImageView.translatesAutoresizingMaskIntoConstraints = false
        favoriteImageView.imageScaling = .scaleProportionallyDown
        setupLayout()
    }

    private func setupLayout() {
        titleLabelToFaviconLeading = titleLabel.leadingAnchor.constraint(equalTo: faviconImageView.trailingAnchor, constant: 10).priority(1000)
        NSLayoutConstraint.activate([
            faviconImageView.heightAnchor.constraint(equalToConstant: 16),
            faviconImageView.widthAnchor.constraint(equalToConstant: 16),
            faviconImageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            faviconImageView.centerYAnchor.constraint(equalTo: centerYAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor)
                .priority(700),
            titleLabelToFaviconLeading,

            bottomAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            menuButton.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor,
                                                constant: 5),
            countLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor,
                                                constant: 5),
            favoriteImageView.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor,
                                                       constant: 5),
            urlLabel.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor,
                                              constant: 6),

            urlLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
//            menuButton.leadingAnchor.constraint(greaterThanOrEqualTo: urlLabel.trailingAnchor),
            favoriteImageView.leadingAnchor.constraint(greaterThanOrEqualTo: urlLabel.trailingAnchor),
            countLabel.leadingAnchor.constraint(greaterThanOrEqualTo: urlLabel.trailingAnchor),

            countLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            trailingAnchor.constraint(equalTo: countLabel.trailingAnchor),

            menuButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            menuButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            menuButton.topAnchor.constraint(equalTo: topAnchor),
            menuButton.bottomAnchor.constraint(equalTo: bottomAnchor),
            menuButton.widthAnchor.constraint(equalToConstant: 28),

            favoriteImageView.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            favoriteImageView.trailingAnchor.constraint(equalTo: menuButton.trailingAnchor),
            favoriteImageView.heightAnchor.constraint(equalToConstant: 15),
            favoriteImageView.widthAnchor.constraint(equalToConstant: 15),
        ])

        faviconImageView.setContentHuggingPriority(NSLayoutConstraint.Priority(rawValue: 251), for: .vertical)
        titleLabel.setContentHuggingPriority(.defaultHigh, for: .vertical)
        urlLabel.setContentHuggingPriority(.init(300), for: .horizontal)
        countLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        if identifier != Self.sizingCellIdentifier {
            faviconImageView.setContentHuggingPriority(NSLayoutConstraint.Priority(rawValue: 251), for: .horizontal)
            titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            titleLabel.setContentHuggingPriority(.init(rawValue: 200), for: .horizontal)
            urlLabel.setContentCompressionResistancePriority(.init(200), for: .horizontal)
            countLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

        } else {
            faviconImageView.setContentCompressionResistancePriority(.required, for: .horizontal)
            titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
            titleLabel.setContentHuggingPriority(.required, for: .horizontal)
            urlLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
            countLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
            self.setContentHuggingPriority(.required, for: .horizontal)
        }
    }

    private func updateUI() {
        if shouldShowMenuButton {
            countLabel.isHidden = self.highlight
            // TODO: when adding to favorites from Edit menu – not updated in menu
            favoriteImageView.isHidden = self.highlight
            menuButton.isShown = self.highlight && faviconImageView.image != nil // don‘t show for custom menu item
            urlLabel.isShown = !urlLabel.stringValue.isEmpty && self.highlight
        }
        if highlight && isInKeyWindow {
            titleLabel.textColor = .selectedMenuItemTextColor
            urlLabel.textColor = .selectedMenuItemTextColor
        } else {
            titleLabel.textColor = .controlTextColor
            urlLabel.textColor = .secondaryLabelColor
        }
    }

    @objc private func cellMenuButtonClicked() {
        delegate?.outlineCellViewRequestedMenu(self)
    }

    // MARK: - Public

    func preferredContentWidth(for node: Any?) -> CGFloat {
        guard let node = node as? BookmarkNode,
              node.representedObject is Bookmark || node.representedObject is BookmarkFolder
                || node.representedObject is PseudoFolder || node.representedObject is MenuItemNode else { return 0 }

        Self.sizingCell.update(from: node, isMenuPopover: true)
        Self.sizingCell.frame = .zero
        Self.sizingCell.layoutSubtreeIfNeeded()

        return Self.sizingCell.frame.width
    }

    func update(from node: BookmarkNode, isMenuPopover: Bool) {
        switch node.representedObject {
        case let bookmark as Bookmark:
            update(from: bookmark, showURL: identifier != Self.sizingCellIdentifier)
        case let folder as BookmarkFolder:
            update(from: folder, showChevron: isMenuPopover)
        case let folder as PseudoFolder:
            update(from: folder)
        case let menuItem as MenuItemNode:
            update(from: menuItem)
        default:
            assertionFailure("Unexpected object \(node.representedObject)")
        }
    }

    func update(from bookmark: Bookmark, showURL: Bool) {
        faviconImageView.image = bookmark.favicon(.small) ?? .bookmarkDefaultFavicon
        titleLabelToFaviconLeading.isActive = true
        titleLabel.stringValue = bookmark.title
        countLabel.stringValue = ""
        urlLabel.stringValue = showURL ? "– " + bookmark.url.dropping(prefix: {
            if let scheme = URL(string: bookmark.url)?.navigationalScheme,
               scheme.isHypertextScheme {
                return scheme.separated()
            } else {
                return ""
            }
        }()) : ""
        favoriteImageView.image = bookmark.isFavorite ? .favoriteFilledBorder : nil
        highlight = false
    }

    func update(from folder: BookmarkFolder, showChevron: Bool) {
        faviconImageView.image = .folder
        titleLabelToFaviconLeading.isActive = true
        titleLabel.stringValue = folder.title
        favoriteImageView.image = showChevron ? .chevronMediumRight16 : nil
        urlLabel.stringValue = ""
        highlight = false

        let totalChildBookmarks = folder.totalChildBookmarks
        if totalChildBookmarks > 0 && !showChevron {
            countLabel.stringValue = String(totalChildBookmarks)
        } else {
            countLabel.stringValue = ""
        }
    }

    func update(from pseudoFolder: PseudoFolder) {
        faviconImageView.image = pseudoFolder.icon
        titleLabelToFaviconLeading.isActive = true
        titleLabel.stringValue = pseudoFolder.name
        countLabel.stringValue = pseudoFolder.count > 0 ? String(pseudoFolder.count) : ""
        favoriteImageView.image = nil
        urlLabel.stringValue = ""
        highlight = false
    }

    func update(from menuItem: MenuItemNode) {
        faviconImageView.image = nil
        titleLabelToFaviconLeading.isActive = false
        titleLabel.stringValue = menuItem.title
        countLabel.stringValue = ""
        favoriteImageView.image = nil
        urlLabel.stringValue = ""
        highlight = false
    }

}

// MARK: - Preview

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
                BookmarkOutlineCellView(identifier: .init("id")),
                BookmarkOutlineCellView(identifier: .init("customItem")),
            ]

            let stackView = NSStackView(views: cells as [NSView])
            stackView.orientation = .vertical
            stackView.spacing = 1
            addAndLayout(stackView)

            cells[0].update(from: Bookmark(id: "1", url: "http://a.b", title: "DuckDuckGo", isFavorite: true), showURL: false)
            cells[1].update(from: Bookmark(id: "1", url: "http://aurl.bu/asdfg/ss=1", title: "Some Page bookmarked", isFavorite: true), showURL: true)
            cells[1].highlight = true
            cells[1].wantsLayer = true
            cells[1].layer!.backgroundColor = NSColor.controlAccentColor.cgColor

            cells[2].update(from: BookmarkFolder(id: "2", title: "Bookmark Folder with a reasonably long name"), showChevron: true)
            cells[3].update(from: BookmarkFolder(id: "2", title: "Bookmark Folder with 42 bookmark children", children: Array(repeating: Bookmark(id: "2", url: "http://a.b", title: "DuckDuckGo", isFavorite: true), count: 42)), showChevron: false)
            PseudoFolder.favorites.count = 64
            cells[4].update(from: PseudoFolder.favorites)
            PseudoFolder.bookmarks.count = 256
            cells[5].update(from: PseudoFolder.bookmarks)

            let node = BookmarkNode(representedObject: MenuItemNode(identifier: "", title: UserText.bookmarksOpenInNewTabs), parent: BookmarkNode.genericRootNode())
            cells[6].update(from: node, isMenuPopover: true)

            widthAnchor.constraint(equalToConstant: 258).isActive = true
            heightAnchor.constraint(equalToConstant: CGFloat((28 + 1) * cells.count)).isActive = true
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

    }
}
#endif
