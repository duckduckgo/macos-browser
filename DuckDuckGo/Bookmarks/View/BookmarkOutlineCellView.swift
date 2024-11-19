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
    static func identifier(for mode: BookmarkOutlineViewDataSource.ContentMode) -> NSUserInterfaceItemIdentifier {
        NSUserInterfaceItemIdentifier("\(mode)_\(self.className())")
    }

    static let sizingCell: BookmarkOutlineCellView = {
        let cell = BookmarkOutlineCellView(identifier: BookmarkOutlineCellView.sizingCellIdentifier)
        cell.highlight = true // include menu button width
        return cell
    }()

    static let rowHeight: CGFloat = 28
    private enum Constants {
        static let minUrlLabelWidth: CGFloat = 42
        static let minWidth: CGFloat = 75
        static let extraWidth: CGFloat = 6
    }

    private lazy var faviconImageView = NSImageView()
    private lazy var titleLabel = NSTextField(string: "Bookmark/Folder")
    private lazy var countLabel = NSTextField(string: "42")
    private lazy var urlLabel = NSTextField(string: "URL")
    private lazy var menuButton = NSButton(title: "", image: .settings, target: self, action: #selector(cellMenuButtonClicked))
    private lazy var favoriteImageView = NSImageView()

    private var leadingConstraint = NSLayoutConstraint()

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

    var contentMode: BookmarkOutlineViewDataSource.ContentMode? {
        BookmarkOutlineViewDataSource.ContentMode.allCases.first { mode in
            Self.identifier(for: mode) == self.identifier
        }
    }

    var shouldShowChevron: Bool {
        contentMode == .bookmarksMenu
    }

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
        translatesAutoresizingMaskIntoConstraints = false

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
        titleLabel.refusesFirstResponder = true
        titleLabel.drawsBackground = false
        titleLabel.font = .systemFont(ofSize: 13)
        titleLabel.textColor = .controlTextColor
        titleLabel.lineBreakMode = .byTruncatingTail

        countLabel.translatesAutoresizingMaskIntoConstraints = false
        countLabel.isEditable = false
        countLabel.isBordered = false
        countLabel.isSelectable = false
        countLabel.refusesFirstResponder = true
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
        leadingConstraint = faviconImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 5)

        NSLayoutConstraint.activate([
            faviconImageView.heightAnchor.constraint(equalToConstant: 16),
            faviconImageView.widthAnchor.constraint(equalToConstant: 16),
            leadingConstraint,
            faviconImageView.centerYAnchor.constraint(equalTo: centerYAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor)
                .priority(700),

            bottomAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            trailingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor,
                                      constant: 0)
                .priority(800),

            urlLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
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

        titleLabel.leadingAnchor.constraint(equalTo: faviconImageView.trailingAnchor,
                                            constant: 10)
            .priority(900)
            .autoDeactivatedWhenViewIsHidden(faviconImageView)
        menuButton.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor,
                                            constant: 5)
            .priority(900)
            .autoDeactivatedWhenViewIsHidden(menuButton)
        countLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor,
                                            constant: 5)
            .priority(900)
            .autoDeactivatedWhenViewIsHidden(countLabel)
        favoriteImageView.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor,
                                                   constant: 5)
            .priority(900)
            .autoDeactivatedWhenViewIsHidden(favoriteImageView)
        urlLabel.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor,
                                          constant: 6)
            .priority(900)
            .autoDeactivatedWhenViewIsHidden(urlLabel)

        faviconImageView.setContentHuggingPriority(.init(251), for: .vertical)
        urlLabel.setContentHuggingPriority(.init(300), for: .horizontal)
        countLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        if identifier != Self.sizingCellIdentifier {
            faviconImageView.setContentHuggingPriority(.init(251), for: .horizontal)
            titleLabel.setContentCompressionResistancePriority(.init(300), for: .horizontal)
            titleLabel.setContentHuggingPriority(.init(301), for: .vertical)
            urlLabel.setContentCompressionResistancePriority(.init(200), for: .horizontal)
            countLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

        } else {
            faviconImageView.setContentCompressionResistancePriority(.required, for: .horizontal)
            titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
            urlLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
            countLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

            trailingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor,
                                      constant: 8)
                .priority(900)
                .isActive = true
        }
    }

    private func updateUI() {
        if titleLabel.isEnabled {
            let isHighlighted = self.highlight && (self.isInKeyWindow || self.contentMode == .foldersOnly)
            countLabel.isHidden = isHighlighted || countLabel.stringValue.isEmpty
            favoriteImageView.isHidden = isHighlighted || favoriteImageView.image == nil
            menuButton.isShown = isHighlighted && faviconImageView.image != nil // don‘t show for custom menu item
            menuButton.contentTintColor = isHighlighted && contentMode != .foldersOnly ? .selectedMenuItemTextColor : .button
            urlLabel.isShown = isHighlighted && !urlLabel.stringValue.isEmpty
        } else {
            menuButton.isHidden = true
            urlLabel.isHidden = true
        }
        if !titleLabel.isEnabled {
            titleLabel.textColor = .disabledControlTextColor
        } else if highlight,
                  isInKeyWindow,
                  contentMode != .foldersOnly {
            titleLabel.textColor = .selectedMenuItemTextColor
            urlLabel.textColor = .selectedMenuItemTextColor
        } else {
            titleLabel.textColor = .controlTextColor
            urlLabel.textColor = .secondaryLabelColor
        }
    }

    override func layout() {
        super.layout()

        // hide URL label if it can‘t fit meaningful text length
        if urlLabel.isShown, urlLabel.frame.width < Constants.minUrlLabelWidth {
            urlLabel.stringValue = ""
            urlLabel.isHidden = true
        }
    }

    @objc private func cellMenuButtonClicked() {
        delegate?.outlineCellViewRequestedMenu(self)
    }

    // MARK: - Public

    static func preferredContentWidth(for object: Any?) -> CGFloat {
        guard let representedObject = (object as? BookmarkNode)?.representedObject ?? object else { return 0 }
        let extraWidth: CGFloat
        let minWidth: CGFloat
        switch representedObject {
        case is Bookmark, is BookmarkFolder, is PseudoFolder:
            minWidth = Constants.minWidth
            extraWidth = Constants.extraWidth
        case is MenuItemNode:
            minWidth = 0
            extraWidth = 0
        default:
            return 0
        }
        sizingCell.frame = .zero
        sizingCell.update(from: representedObject)
        sizingCell.layoutSubtreeIfNeeded()

        return max(minWidth, sizingCell.frame.width + extraWidth)
    }

    func update(from object: Any, isSearch: Bool = false) {
        let representedObject = (object as? BookmarkNode)?.representedObject ?? object
        switch representedObject {
        case let bookmark as Bookmark:
            update(from: bookmark, isSearch: isSearch, showURL: identifier != Self.sizingCellIdentifier)
        case let folder as BookmarkFolder:
            update(from: folder, isSearch: isSearch)
        case let folder as PseudoFolder:
            update(from: folder)
        case let menuItem as MenuItemNode:
            update(from: menuItem)
        default:
            assertionFailure("Unexpected object \(object).\(String(describing: (object as? BookmarkNode)?.representedObject))")
        }
    }

    func update(from bookmark: Bookmark, isSearch: Bool = false, showURL: Bool) {
        faviconImageView.image = bookmark.favicon(.small) ?? .bookmarkDefaultFavicon
        faviconImageView.isHidden = false
        titleLabel.stringValue = bookmark.title
        titleLabel.isEnabled = true
        countLabel.stringValue = ""
        countLabel.isHidden = true
        urlLabel.stringValue = showURL ? "– " + bookmark.url.dropping(prefix: {
            if let scheme = URL(string: bookmark.url)?.navigationalScheme,
               scheme.isHypertextScheme {
                return scheme.separated()
            } else {
                return ""
            }
        }()) : ""
        urlLabel.isHidden = urlLabel.stringValue.isEmpty
        self.toolTip = bookmark.url
        favoriteImageView.image = bookmark.isFavorite ? .favoriteFilledBorder : nil
        favoriteImageView.isHidden = favoriteImageView.image == nil

        updateConstraints(isSearch: isSearch)
    }

    func update(from folder: BookmarkFolder, isSearch: Bool = false) {
        faviconImageView.image = .folder
        faviconImageView.isHidden = false
        titleLabel.stringValue = folder.title
        titleLabel.isEnabled = true
        favoriteImageView.image = shouldShowChevron ? .chevronMediumRight16 : nil
        favoriteImageView.isHidden = favoriteImageView.image == nil
        urlLabel.stringValue = ""
        self.toolTip = nil

        let totalChildBookmarks = folder.totalChildBookmarks
        if totalChildBookmarks > 0 && !shouldShowChevron {
            countLabel.stringValue = String(totalChildBookmarks)
            countLabel.isHidden = false
        } else {
            countLabel.stringValue = ""
            countLabel.isHidden = true
        }
        updateConstraints(isSearch: isSearch)
    }

    private func updateConstraints(isSearch: Bool) {
        leadingConstraint.constant = isSearch ? -8 : 5
    }

    func update(from pseudoFolder: PseudoFolder) {
        faviconImageView.image = pseudoFolder.icon
        faviconImageView.isHidden = false
        titleLabel.stringValue = pseudoFolder.name
        titleLabel.isEnabled = true
        countLabel.stringValue = pseudoFolder.count > 0 ? String(pseudoFolder.count) : ""
        countLabel.isHidden = countLabel.stringValue.isEmpty
        favoriteImageView.image = nil
        favoriteImageView.isHidden = true
        urlLabel.stringValue = ""
        self.toolTip = nil
    }

    func update(from menuItem: MenuItemNode) {
        faviconImageView.image = nil
        faviconImageView.isHidden = true
        titleLabel.stringValue = menuItem.title
        titleLabel.isEnabled = menuItem.isEnabled
        countLabel.stringValue = ""
        favoriteImageView.image = nil
        favoriteImageView.isHidden = true
        urlLabel.stringValue = ""
        urlLabel.isHidden = true
        self.toolTip = nil
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
                BookmarkOutlineCellView(identifier: .init("")),
                BookmarkOutlineCellView(identifier: .init("")),
                BookmarkOutlineCellView(identifier: .init("")),
                BookmarkOutlineCellView(identifier: BookmarkOutlineCellView.identifier(for: .bookmarksMenu)),
                BookmarkOutlineCellView(identifier: .init("")),
                BookmarkOutlineCellView(identifier: .init("")),
                BookmarkOutlineCellView(identifier: .init("")),
                BookmarkOutlineCellView(identifier: BookmarkOutlineCellView.identifier(for: .bookmarksMenu)),
                BookmarkOutlineCellView(identifier: BookmarkOutlineCellView.identifier(for: .bookmarksMenu)),
                BookmarkOutlineCellView(identifier: .init("")),
                BookmarkOutlineCellView(identifier: .init("")),
            ]

            let stackView = NSStackView(views: cells as [NSView])
            stackView.orientation = .vertical
            stackView.spacing = 1
            addAndLayout(stackView)

            cells[0].update(from: Bookmark(id: "1", url: "http://a.b", title: "DuckDuckGo", isFavorite: true), showURL: false)
            cells[1].update(from: Bookmark(id: "2", url: "http://aurl.bu/asdfg/ss=1", title: "Some Page bookmarked", isFavorite: true), showURL: true)
            cells[1].highlight = true
            cells[1].wantsLayer = true
            cells[1].layer!.backgroundColor = NSColor.controlAccentColor.cgColor

            let bkm2 = Bookmark(id: "3", url: "http://a.b", title: "Bookmark with longer title to test width", isFavorite: false)
            cells[2].update(from: bkm2, showURL: false)

            cells[3].update(from: BookmarkFolder(id: "4", title: "Bookmark Folder with a reasonably long name"))
            cells[4].update(from: BookmarkFolder(id: "5", title: "Bookmark Folder with 42 bookmark children", children: Array(repeating: Bookmark(id: "2", url: "http://a.b", title: "DuckDuckGo", isFavorite: true), count: 42)))
            PseudoFolder.favorites.count = 64
            cells[5].update(from: PseudoFolder.favorites)
            PseudoFolder.bookmarks.count = 256
            cells[6].update(from: PseudoFolder.bookmarks)

            let node = BookmarkNode(representedObject: MenuItemNode(identifier: "", title: UserText.bookmarksOpenInNewTabs, isEnabled: true), parent: BookmarkNode.genericRootNode())
            cells[7].update(from: node)

            let emptyNode = BookmarkNode(representedObject: MenuItemNode(identifier: "", title: UserText.bookmarksBarFolderEmpty, isEnabled: false), parent: BookmarkNode.genericRootNode())
            cells[8].update(from: emptyNode)

            let sbkm = Bookmark(id: "3", url: "http://a.b", title: "Bookmark in Search mode", isFavorite: false)
            cells[9].update(from: sbkm, isSearch: true, showURL: false)
            cells[10].update(from: BookmarkFolder(id: "5", title: "Folder in Search mode", children: Array(repeating: Bookmark(id: "2", url: "http://a.b", title: "DuckDuckGo", isFavorite: true), count: 42)), isSearch: true)

            widthAnchor.constraint(equalToConstant: 258).isActive = true
            heightAnchor.constraint(equalToConstant: CGFloat((28 + 1) * cells.count)).isActive = true
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

    }
}
#endif
