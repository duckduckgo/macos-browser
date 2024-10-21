//
//  BookmarkTableCellView.swift
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

@objc protocol BookmarkTableCellViewDelegate: AnyObject {

    func bookmarkTableCellViewRequestedMenu(_ sender: NSButton, cell: BookmarkTableCellView)

}

final class BookmarkTableCellView: NSTableCellView {

    private lazy var faviconImageView = NSImageView(image: .bookmark)

    private lazy var titleLabel = NSTextField(string: "Bookmark")
    private lazy var bookmarkURLLabel = NSTextField(string: "URL")
    private lazy var accessoryImageView = NSImageView(image: .forward)

    private lazy var containerView = NSView()

    private lazy var menuButton = NSButton(title: "", image: .settings, target: self, action: #selector(cellMenuButtonClicked))

    @objc func cellMenuButtonClicked(_ sender: NSButton) {
        delegate?.bookmarkTableCellViewRequestedMenu(sender, cell: self)
    }

    weak var delegate: BookmarkTableCellViewDelegate?

    var isSelected = false {
        didSet {
            updateColors()
            updateTitleLabelValue()
        }
    }

    private var entity: BaseBookmarkEntity?
    private var trackingArea: NSTrackingArea?
    private var mouseInside: Bool = false {
        didSet {
            guard self.entity != nil else {
                menuButton.isHidden = true
                return
            }

            accessoryImageView.isHidden = mouseInside
            menuButton.isHidden = !mouseInside

            if !mouseInside {
                resetAppearanceFromBookmark()
            }

            updateTitleLabelValue()
        }
    }

    init(identifier: NSUserInterfaceItemIdentifier, entity: BaseBookmarkEntity? = nil) {
        super.init(frame: NSRect(x: 0, y: 0, width: 462, height: 84))
        self.identifier = identifier

        setupUI()
        setupLayout()
        resetCellState()

        if let bookmark = entity as? Bookmark {
            update(from: bookmark)
        } else if let folder = entity as? BookmarkFolder {
            update(from: folder)
        } else if entity != nil {
            assertionFailure("Unsupported Bookmark Entity: \(entity!)")
        }
    }

    required init?(coder: NSCoder) {
        fatalError("\(type(of: self)): Bad initializer")
    }

    private func setupUI() {
        autoresizingMask = [.width, .height]

        addSubview(containerView)

        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(faviconImageView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(menuButton)
        containerView.addSubview(accessoryImageView)

        faviconImageView.contentTintColor = .suggestionIcon
        faviconImageView.wantsLayer = true
        faviconImageView.layer?.cornerRadius = 2.0
        faviconImageView.setContentHuggingPriority(.init(rawValue: 251), for: .horizontal)
        faviconImageView.setContentHuggingPriority(.init(rawValue: 251), for: .vertical)
        faviconImageView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.focusRingType = .none
        titleLabel.isEditable = false
        titleLabel.isBordered = false
        titleLabel.isSelectable = false
        titleLabel.drawsBackground = false
        titleLabel.font = .systemFont(ofSize: 13)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.cell?.usesSingleLineMode = true
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleLabel.setContentHuggingPriority(.defaultHigh, for: .vertical)
        titleLabel.setContentHuggingPriority(.init(rawValue: 251), for: .horizontal)

        accessoryImageView.translatesAutoresizingMaskIntoConstraints = false

        menuButton.contentTintColor = .button
        menuButton.translatesAutoresizingMaskIntoConstraints = false
        menuButton.isBordered = false
        menuButton.isHidden = true
        menuButton.sendAction(on: .leftMouseDown)
        menuButton.setAccessibilityIdentifier("BookmarkTableCellView.menuButton")
    }

    private func setupLayout() {
        NSLayoutConstraint.activate([
        trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: 3),
        containerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 3),
        bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: 3),
        containerView.topAnchor.constraint(equalTo: topAnchor, constant: 3),

        menuButton.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 8),
        faviconImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 6),

        accessoryImageView.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
        titleLabel.leadingAnchor.constraint(equalTo: faviconImageView.trailingAnchor, constant: 8),
        trailingAnchor.constraint(equalTo: accessoryImageView.trailingAnchor, constant: 3),
        faviconImageView.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
        trailingAnchor.constraint(equalTo: menuButton.trailingAnchor, constant: 2),

        menuButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),

        menuButton.heightAnchor.constraint(equalToConstant: 32),
        menuButton.widthAnchor.constraint(equalToConstant: 28),

        faviconImageView.heightAnchor.constraint(equalToConstant: 16),
        faviconImageView.widthAnchor.constraint(equalToConstant: 16),

        bottomAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
        titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 5),

        accessoryImageView.widthAnchor.constraint(equalToConstant: 22),
        accessoryImageView.heightAnchor.constraint(equalToConstant: 32),
        ])
    }

    override var backgroundStyle: NSView.BackgroundStyle {
        didSet {
            faviconImageView.contentTintColor = isSelected ? .white : .black
            updateTitleLabelValue()
        }
    }

    override var draggingImageComponents: [NSDraggingImageComponent] {
        let faviconComponent = NSDraggingImageComponent(key: .icon)
        faviconComponent.contents = faviconImageView.image
        faviconComponent.frame = faviconImageView.frame

        let labelComponent = NSDraggingImageComponent(key: .label)
        labelComponent.contents = titleLabel.imageRepresentation()
        labelComponent.frame = titleLabel.frame

        return [faviconComponent, labelComponent]
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        ensureTrackingArea()

        if !trackingAreas.contains(trackingArea!) {
            addTrackingArea(trackingArea!)
        }
    }

    override func mouseEntered(with event: NSEvent) {
        mouseInside = true
    }

    override func mouseExited(with event: NSEvent) {
        mouseInside = false
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        resetCellState()
    }

    func update(from bookmark: Bookmark) {
        self.entity = bookmark

        faviconImageView.image = bookmark.favicon(.small) ?? .bookmarkDefaultFavicon

        faviconImageView.setAccessibilityIdentifier("BookmarkTableCellView.favIconImageView")
        if bookmark.isFavorite {
            accessoryImageView.isHidden = false
        }

        accessoryImageView.image = bookmark.isFavorite ? .favoriteFilledBorder : nil
        accessoryImageView.setAccessibilityIdentifier("BookmarkTableCellView.accessoryImageView")
        accessoryImageView.setAccessibilityValue(bookmark.isFavorite ? "Favorited" : "Unfavorited")
        titleLabel.stringValue = bookmark.title
        primaryTitleLabelValue = bookmark.title
        tertiaryTitleLabelValue = bookmark.url
    }

    func update(from folder: BookmarkFolder) {
        self.entity = folder

        faviconImageView.image = .folder
        accessoryImageView.image = .chevronMediumRight16
        primaryTitleLabelValue = folder.title
        tertiaryTitleLabelValue = nil
    }

    private func resetCellState() {
        self.entity = nil
        mouseInside = false
    }

    private func updateColors() {
        titleLabel.textColor = isSelected ? .white : .controlTextColor
        menuButton.contentTintColor = isSelected ? .white : .button
        faviconImageView.contentTintColor = isSelected ? .white : .suggestionIcon
        accessoryImageView.contentTintColor = isSelected ? .white : .suggestionIcon
    }

    private func ensureTrackingArea() {
        if trackingArea == nil {
            trackingArea = NSTrackingArea(rect: .zero, options: [.inVisibleRect, .activeAlways, .mouseEnteredAndExited], owner: self, userInfo: nil)
        }
    }

    /// Provides the primary value displayed in the title label. This value will be rendered with a black text color.
    private var primaryTitleLabelValue = "" {
        didSet {
            updateTitleLabelValue()
        }
    }

    /// Provides the tertiary value displayed in the title label when the cell is selected. This value will be rendered with a lighter text color to the main text.
    private var tertiaryTitleLabelValue: String? {
        didSet {
            updateTitleLabelValue()
        }
    }

    private func resetAppearanceFromBookmark() {
        if let bookmark = self.entity as? Bookmark {
            update(from: bookmark)
        } else if let folder = self.entity as? BookmarkFolder {
            update(from: folder)
        } else {
            assertionFailure("\(#file): Failed to update cell from \(String(describing: entity))")
        }
    }

    private func updateTitleLabelValue() {
        if let tertiaryValue = tertiaryTitleLabelValue, mouseInside {
            showTertiaryValueInTitleLabel(tertiaryValue)
        } else {
            hideTertiaryValueInTitleLabel()
        }
    }

    private func showTertiaryValueInTitleLabel(_ tertiaryValue: String) {
        titleLabel.stringValue = ""
        titleLabel.attributedStringValue = buildTitleAttributedString(tertiaryValue: tertiaryValue)
    }

    private func hideTertiaryValueInTitleLabel() {
        titleLabel.attributedStringValue = NSAttributedString()
        titleLabel.stringValue = primaryTitleLabelValue
    }

    private func buildTitleAttributedString(tertiaryValue: String) -> NSAttributedString {
        let color = isSelected ? NSColor.white : NSColor.labelColor

        let titleAttributes = [NSAttributedString.Key.foregroundColor: color]
        let titleString = NSMutableAttributedString(string: primaryTitleLabelValue, attributes: titleAttributes)

        let urlColor = isSelected ? NSColor.white.withAlphaComponent(0.6) : NSColor.tertiaryLabelColor

        let urlAttributes = [NSAttributedString.Key.foregroundColor: urlColor]
        let urlString = NSAttributedString(string: " – \(tertiaryValue)", attributes: urlAttributes)

        titleString.append(urlString)

        return titleString
    }

}

#if DEBUG
@available(macOS 14.0, *)
#Preview {
    BookmarkTableCellView.PreviewView(cell: BookmarkTableCellView(identifier: .init("id"), entity: Bookmark(id: "1", url: URL.duckDuckGo.absoluteString, title: "DuckDuckGo", isFavorite: false)))
}

extension BookmarkTableCellView {
    final class PreviewView: NSView, BookmarkTableCellViewDelegate {

        let cell: BookmarkTableCellView

        init(cell: BookmarkTableCellView) {
            self.cell = cell
            super.init(frame: .zero)
            wantsLayer = true
            layer!.backgroundColor = NSColor.white.cgColor

            translatesAutoresizingMaskIntoConstraints = true
            widthAnchor.constraint(equalToConstant: 512).isActive = true

            cell.frame = bounds
            self.addSubview(cell)

            cell.delegate = self
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func bookmarkTableCellViewRequestedMenu(_ sender: NSButton, cell: BookmarkTableCellView) {}

        func bookmarkTableCellViewToggledFavorite(cell: BookmarkTableCellView) {
            (cell.entity as? Bookmark)?.isFavorite.toggle()
        }
    }
}
#endif
